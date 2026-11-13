<?php
namespace app\controller\api;

use think\facade\Request;
use think\facade\Session;
use app\service\AdminAuth;

class Auth extends BaseController
{
    /**
     * 登录
     * @return \think\Response
     */
    public function login()
    {
        $username = Request::param('username');
        $password = Request::param('password');
        
        if (empty($username) || empty($password)) {
            return $this->error('用户名或密码不能为空');
        }
        
        $ip = AdminAuth::clientIp();
        if (AdminAuth::blocked($ip)) {
            return $this->error('登录失败次数过多，请 15 分钟后再试', 429);
        }

        if (!AdminAuth::checkLogin((string)$username, (string)$password)) {
            $left = AdminAuth::recordFailure($ip);
            return $this->error($left > 0 ? '用户名或密码错误' : '登录失败次数过多，请 15 分钟后再试');
        }
        AdminAuth::clearFailures($ip);

        $token = AdminAuth::issueToken();

        // 设置Session
        Session::set('admin', $username);

        return $this->success([
            'accessToken' => $token,
            'username' => $username,
            'defaultPassword' => AdminAuth::usingDefaultPassword()
        ]);
    }
    
    /**
     * 退出登录
     * @return \think\Response
     */
    public function logout()
    {
        Session::delete('admin');
        return $this->success(null, '退出成功');
    }
} 