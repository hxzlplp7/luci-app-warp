'use strict';
'require view';
'require form';
'require fs';
'require ui';
'require uci';
'require poll';
'require rpc';

var callServiceList = rpc.declare({
    object: 'service',
    method: 'list',
    params: ['name'],
    expect: { '': {} }
});

return view.extend({
    load: function () {
        return Promise.all([
            uci.load('warp'),
            L.resolveDefault(fs.exec('/usr/bin/wg', ['show', 'warp']), { stdout: '' }),
            L.resolveDefault(fs.read('/etc/warp/account.json'), null)
        ]);
    },

    render: function (data) {
        var wgStatus = data[1].stdout || '';
        var accountExists = data[2] !== null;

        var m, s, o;

        m = new form.Map('warp', _('Cloudflare WARP'),
            _('Cloudflare WARP 是一个免费的VPN服务，可以加密您的网络流量并提供更快、更安全的互联网访问。'));

        // 状态区域
        s = m.section(form.NamedSection, 'config', 'warp', _('运行状态'));
        s.anonymous = true;

        o = s.option(form.DummyValue, '_status', _('服务状态'));
        o.rawhtml = true;
        o.cfgvalue = function () {
            var isRunning = wgStatus.indexOf('interface: warp') !== -1;
            var hasHandshake = wgStatus.indexOf('latest handshake') !== -1;

            var status = '<span style="color: ' + (isRunning ? '#28a745' : '#dc3545') + '; font-weight: bold;">';
            status += isRunning ? '✓ 运行中' : '✗ 已停止';
            status += '</span>';

            if (isRunning && hasHandshake) {
                status += ' | <span style="color: #28a745;">已连接</span>';
            }

            return status;
        };

        o = s.option(form.DummyValue, '_account', _('账户状态'));
        o.rawhtml = true;
        o.cfgvalue = function () {
            return accountExists
                ? '<span style="color: #28a745; font-weight: bold;">✓ 已注册</span>'
                : '<span style="color: #ffc107; font-weight: bold;">⚠ 未注册</span>';
        };

        // 基本设置
        s = m.section(form.NamedSection, 'config', 'warp', _('基本设置'));
        s.anonymous = true;

        o = s.option(form.Flag, 'enabled', _('启用'));
        o.rmempty = false;
        o.default = '0';

        o = s.option(form.Value, 'endpoint', _('服务器地址'));
        o.default = 'engage.cloudflareclient.com:2408';
        o.rmempty = false;
        o.description = _('WARP 服务器端点地址和端口');

        o = s.option(form.Value, 'mtu', _('MTU'));
        o.datatype = 'range(1280,1500)';
        o.default = '1280';

        o = s.option(form.Value, 'dns', _('DNS 服务器'));
        o.default = '1.1.1.1';
        o.description = _('使用的DNS服务器地址');

        o = s.option(form.Flag, 'ipv6', _('启用 IPv6'));
        o.default = '1';

        // 代理设置
        s = m.section(form.NamedSection, 'config', 'warp', _('代理设置'));
        s.anonymous = true;

        o = s.option(form.Flag, 'global_proxy', _('全局代理'));
        o.default = '1';
        o.description = _('启用后，所有流量都将通过WARP');

        o = s.option(form.Flag, 'bypass_china', _('绕过中国大陆IP'));
        o.default = '0';
        o.description = _('启用后，中国大陆IP将不经过WARP直连');

        // SOCKS代理
        s = m.section(form.NamedSection, 'config', 'warp', _('SOCKS5 代理'));
        s.anonymous = true;

        o = s.option(form.Flag, 'socks_enabled', _('启用 SOCKS5 代理'));
        o.default = '1';
        o.description = _('在本地开启 SOCKS5 代理端口');

        o = s.option(form.Value, 'socks_port', _('SOCKS5 端口'));
        o.datatype = 'port';
        o.default = '1080';
        o.depends('socks_enabled', '1');

        // 前置代理
        s = m.section(form.NamedSection, 'config', 'warp', _('前置代理'));
        s.anonymous = true;
        s.description = _('通过本地已有的代理端口连接 WARP 服务器（如 Clash、v2ray 等提供的本地代理）');

        o = s.option(form.Flag, 'pre_proxy_enabled', _('启用前置代理'));
        o.default = '0';
        o.description = _('开启后 WARP 将通过指定的本地代理端口出站');

        o = s.option(form.ListValue, 'pre_proxy_type', _('代理类型'));
        o.value('socks5', 'SOCKS5');
        o.value('http', 'HTTP');
        o.default = 'socks5';
        o.depends('pre_proxy_enabled', '1');

        o = s.option(form.Value, 'pre_proxy_addr', _('代理地址'));
        o.datatype = 'host';
        o.default = '127.0.0.1';
        o.placeholder = '127.0.0.1';
        o.depends('pre_proxy_enabled', '1');
        o.description = _('本地代理监听地址，通常是 127.0.0.1');

        o = s.option(form.Value, 'pre_proxy_port', _('代理端口'));
        o.datatype = 'port';
        o.placeholder = '7890';
        o.depends('pre_proxy_enabled', '1');
        o.description = _('本地代理端口，如 Clash 的 7890 或 v2ray 的 10808');

        // 账户信息
        s = m.section(form.NamedSection, 'config', 'warp', _('账户信息'));
        s.anonymous = true;

        o = s.option(form.DummyValue, 'address_v4', _('IPv4 地址'));
        o.cfgvalue = function (section_id) {
            return uci.get('warp', section_id, 'address_v4') || _('未配置');
        };

        o = s.option(form.DummyValue, 'address_v6', _('IPv6 地址'));
        o.cfgvalue = function (section_id) {
            return uci.get('warp', section_id, 'address_v6') || _('未配置');
        };

        o = s.option(form.Value, 'license_key', _('WARP+ License Key'));
        o.password = true;
        o.rmempty = true;
        o.description = _('如果您有WARP+ License Key，可以在此输入以升级');

        // 高级设置
        s = m.section(form.NamedSection, 'config', 'warp', _('高级设置'));
        s.anonymous = true;

        o = s.option(form.Value, 'private_key', _('私钥'));
        o.password = true;
        o.rmempty = true;

        o = s.option(form.Value, 'public_key', _('公钥'));
        o.rmempty = true;
        o.readonly = true;

        o = s.option(form.Value, 'reserved', _('Reserved 字节'));
        o.rmempty = true;

        return m.render();
    }
});
