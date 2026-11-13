<?php
declare (strict_types = 1);

namespace app\service;

use think\facade\Cache;
use think\facade\Db;

/**
 * 后台登录：密码哈希、登录令牌、登录失败限制、签名比较。
 *
 * - 密码存成 password_hash；旧版明文密码在第一次登录成功时自动转成哈希。
 * - 令牌 "v2.<过期时间>.<HMAC>"：用服务器随机密钥签名，带过期时间；
 *   改密码或改用户名后旧令牌全部失效。
 * - 同一 IP 15 分钟内失败 10 次，暂停登录 15 分钟。
 */
class AdminAuth
{
    const TOKEN_TTL = 7 * 86400;
    const FAIL_LIMIT = 10;
    const FAIL_WINDOW = 900;

    public static function setting(string $key): string
    {
        $v = Db::name('setting')->where('vkey', $key)->value('vvalue');
        return $v === null ? '' : (string)$v;
    }

    public static function setSetting(string $key, string $value): void
    {
        if (Db::name('setting')->where('vkey', $key)->find()) {
            Db::name('setting')->where('vkey', $key)->update(['vvalue' => $value]);
        } else {
            Db::name('setting')->insert(['vkey' => $key, 'vvalue' => $value]);
        }
    }

    public static function isHash(string $stored): bool
    {
        return (password_get_info($stored)['algo'] ?? null) !== null;
    }

    public static function hashPassword(string $plain): string
    {
        return password_hash($plain, PASSWORD_DEFAULT);
    }

    /** 校验用户名和密码；旧版明文密码校验通过后改存哈希。 */
    public static function checkLogin(string $user, string $pass): bool
    {
        $storedUser = self::setting('user');
        $stored = self::setting('pass');
        if ($storedUser === '' || $stored === '' || $pass === '') {
            return false;
        }
        $userOk = hash_equals($storedUser, $user);
        if (self::isHash($stored)) {
            $passOk = password_verify($pass, $stored);
            if ($userOk && $passOk && password_needs_rehash($stored, PASSWORD_DEFAULT)) {
                self::setSetting('pass', self::hashPassword($pass));
            }
        } else {
            $passOk = hash_equals($stored, $pass);
            if ($userOk && $passOk) {
                self::setSetting('pass', self::hashPassword($pass));
            }
        }
        return $userOk && $passOk;
    }

    /** 默认账号密码还没改。 */
    public static function usingDefaultPassword(): bool
    {
        $stored = self::setting('pass');
        return self::isHash($stored) ? password_verify('admin', $stored) : $stored === 'admin';
    }

    /** 保存设置里的新密码：空的表示不修改。 */
    public static function savePassword($pass): void
    {
        if (!is_string($pass) || $pass === '') {
            return;
        }
        self::setSetting('pass', self::hashPassword($pass));
    }

    private static function secret(): string
    {
        $s = self::setting('token_secret');
        if (strlen($s) < 32) {
            $s = bin2hex(random_bytes(32));
            self::setSetting('token_secret', $s);
        }
        return $s;
    }

    private static function mac(int $exp): string
    {
        return hash_hmac('sha256', $exp . '|' . self::setting('user') . '|' . self::setting('pass'), self::secret());
    }

    public static function issueToken(): string
    {
        $exp = time() + self::TOKEN_TTL;
        return 'v2.' . $exp . '.' . self::mac($exp);
    }

    public static function checkToken($token): bool
    {
        if (!is_string($token)) {
            return false;
        }
        if (stripos($token, 'Bearer ') === 0) {
            $token = substr($token, 7);
        }
        $parts = explode('.', $token);
        if (count($parts) !== 3 || $parts[0] !== 'v2' || !ctype_digit($parts[1])) {
            return false;
        }
        $exp = (int)$parts[1];
        if ($exp < time()) {
            return false;
        }
        return hash_equals(self::mac($exp), $parts[2]);
    }

    /**
     * 登录限制用的客户端地址：直连时用对端地址；经过本机或内网代理时，
     * 从 X-Forwarded-For 右边起找第一个公网地址（代理自己加的不可伪造）。
     */
    public static function clientIp(): string
    {
        $remote = $_SERVER['REMOTE_ADDR'] ?? '';
        if (!self::isPrivate($remote)) {
            return $remote;
        }
        $chain = array_map('trim', explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'] ?? ''));
        $real = trim($_SERVER['HTTP_X_REAL_IP'] ?? '');
        if ($real !== '') {
            $chain[] = $real;
        }
        for ($i = count($chain) - 1; $i >= 0; $i--) {
            if ($chain[$i] !== '' && filter_var($chain[$i], FILTER_VALIDATE_IP) && !self::isPrivate($chain[$i])) {
                return $chain[$i];
            }
        }
        return $remote;
    }

    private static function isPrivate(string $ip): bool
    {
        return $ip === '' || !filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE);
    }

    private static function failKey(string $ip): string
    {
        return 'login_fail_' . md5($ip);
    }

    public static function blocked(string $ip): bool
    {
        return (int)Cache::get(self::failKey($ip), 0) >= self::FAIL_LIMIT;
    }

    public static function recordFailure(string $ip): int
    {
        $k = self::failKey($ip);
        $n = (int)Cache::get($k, 0) + 1;
        Cache::set($k, $n, self::FAIL_WINDOW);
        return max(0, self::FAIL_LIMIT - $n);
    }

    public static function clearFailures(string $ip): void
    {
        Cache::delete(self::failKey($ip));
    }

    /** 比较 md5 签名：非空、长度相同、常量时间。 */
    public static function signOk($expected, $given): bool
    {
        return is_string($given) && $given !== '' && is_string($expected) && hash_equals($expected, strtolower($given));
    }

    /**
     * 防止同一个监控端推送被重放：同一签名 7 天内只接受一次。
     * 返回 false 表示这条推送已经处理过。
     */
    public static function firstUse(string $sign): bool
    {
        $k = 'push_seen_' . $sign;
        if (Cache::has($k)) {
            return false;
        }
        Cache::set($k, 1, 7 * 86400);
        return true;
    }

    public static function forget(string $sign): void
    {
        Cache::delete('push_seen_' . $sign);
    }
}
