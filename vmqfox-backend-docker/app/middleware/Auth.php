<?php
declare (strict_types = 1);

namespace app\middleware;

use app\service\AdminAuth;
use think\facade\Session;
use think\Response;

class Auth
{
    /**
     * 处理请求
     *
     * @param \think\Request $request
     * @param \Closure       $next
     * @return Response
     */
    public function handle($request, \Closure $next)
    {
        // 获取请求头中的Token
        $token = $request->header('Authorization');
        
        // 如果没有Token，尝试从Session中获取
        if (!$token && Session::has('admin')) {
            return $next($request);
        }
        
        // 如果没有Token，返回未授权错误
        if (!$token) {
            return Response::create([
                'code' => 401,
                'msg' => '未授权，请先登录',
                'data' => null
            ], 'json');
        }
        
        // 验证Token（带过期时间，改密码后失效）
        if (!AdminAuth::checkToken($token)) {
            return Response::create([
                'code' => 401,
                'msg' => '令牌无效，请重新登录',
                'data' => null
            ], 'json');
        }
        
        // Token验证通过，继续处理请求
        return $next($request);
    }
} 