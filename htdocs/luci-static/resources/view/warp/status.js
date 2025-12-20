'use strict';
'require view';
'require fs';
'require ui';
'require uci';
'require poll';
'require rpc';

var callWarpAPI = rpc.declare({
    object: 'luci',
    method: 'exec',
    params: ['command'],
    expect: { stdout: '' }
});

return view.extend({
    load: function () {
        return Promise.all([
            uci.load('warp'),
            L.resolveDefault(fs.exec('/usr/bin/wg', ['show', 'warp']), { code: 1, stdout: '' }),
            L.resolveDefault(fs.stat('/etc/warp/account.json'), null),
            L.resolveDefault(fs.exec('/bin/netstat', ['-tln']), { stdout: '' })
        ]);
    },

    pollStatus: function () {
        return Promise.all([
            L.resolveDefault(fs.exec('/usr/bin/wg', ['show', 'warp']), { code: 1, stdout: '' }),
            L.resolveDefault(fs.stat('/etc/warp/account.json'), null),
            L.resolveDefault(fs.exec('/bin/netstat', ['-tln']), { stdout: '' })
        ]).then(L.bind(function (data) {
            this.updateStatusDisplay(data);
        }, this));
    },

    updateStatusDisplay: function (data) {
        var wgOutput = data[0].stdout || '';
        var accountExists = data[1] !== null;
        var netstatOutput = data[2].stdout || '';

        var isRunning = wgOutput.indexOf('interface: warp') !== -1;
        var hasHandshake = wgOutput.indexOf('latest handshake') !== -1;
        var socksPort = uci.get('warp', 'config', 'socks_port') || '1080';
        var socksRunning = netstatOutput.indexOf(':' + socksPort) !== -1;

        // 更新状态显示
        var statusEl = document.getElementById('warp-status');
        var connEl = document.getElementById('warp-connection');
        var accountEl = document.getElementById('warp-account');
        var socksEl = document.getElementById('warp-socks');
        var handshakeEl = document.getElementById('warp-handshake');
        var transferEl = document.getElementById('warp-transfer');

        if (statusEl) {
            statusEl.innerHTML = isRunning
                ? '<span class="badge success">运行中</span>'
                : '<span class="badge error">已停止</span>';
        }

        if (connEl) {
            connEl.innerHTML = hasHandshake
                ? '<span class="badge success">已连接</span>'
                : (isRunning ? '<span class="badge warning">连接中...</span>' : '<span class="badge error">未连接</span>');
        }

        if (accountEl) {
            accountEl.innerHTML = accountExists
                ? '<span class="badge success">已注册</span>'
                : '<span class="badge warning">未注册</span>';
        }

        if (socksEl) {
            socksEl.innerHTML = socksRunning
                ? '<span class="badge success">运行中 (端口 ' + socksPort + ')</span>'
                : '<span class="badge warning">未启动</span>';
        }

        // 解析握手时间和流量
        if (handshakeEl) {
            var handshakeMatch = wgOutput.match(/latest handshake: ([^\n]+)/);
            handshakeEl.textContent = handshakeMatch ? handshakeMatch[1] : '-';
        }

        if (transferEl) {
            var transferMatch = wgOutput.match(/transfer: ([^\n]+)/);
            transferEl.textContent = transferMatch ? transferMatch[1] : '-';
        }
    },

    handleAction: function (action) {
        var self = this;
        ui.showModal(_('请稍候...'), [
            E('p', { 'class': 'spinning' }, _('正在执行操作...'))
        ]);

        var cmd;
        switch (action) {
            case 'register':
                cmd = '/usr/bin/warp-manager register';
                break;
            case 'start':
                cmd = '/etc/init.d/warp start';
                break;
            case 'stop':
                cmd = '/etc/init.d/warp stop';
                break;
            case 'restart':
                cmd = '/etc/init.d/warp restart';
                break;
            case 'test':
                cmd = 'curl -s --socks5 127.0.0.1:' + (uci.get('warp', 'config', 'socks_port') || '1080') + ' --max-time 10 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null || curl -s --max-time 10 https://www.cloudflare.com/cdn-cgi/trace';
                break;
            case 'reset':
                cmd = '/usr/bin/warp-manager reset';
                break;
            default:
                ui.hideModal();
                return;
        }

        return fs.exec('/bin/sh', ['-c', cmd]).then(function (res) {
            ui.hideModal();

            if (action === 'test') {
                var output = res.stdout || '';
                var warpStatus = output.match(/warp=([^\n]+)/);
                var ip = output.match(/ip=([^\n]+)/);
                var loc = output.match(/loc=([^\n]+)/);

                ui.showModal(_('连接测试结果'), [
                    E('div', { 'class': 'cbi-section' }, [
                        E('p', {}, [
                            E('strong', {}, 'WARP 状态: '),
                            warpStatus ? warpStatus[1] : _('未知')
                        ]),
                        E('p', {}, [
                            E('strong', {}, '出口 IP: '),
                            ip ? ip[1] : _('未知')
                        ]),
                        E('p', {}, [
                            E('strong', {}, '位置: '),
                            loc ? loc[1] : _('未知')
                        ])
                    ]),
                    E('div', { 'class': 'right' }, [
                        E('button', {
                            'class': 'btn',
                            'click': ui.hideModal
                        }, _('关闭'))
                    ])
                ]);
            } else {
                ui.addNotification(null, E('p', _('操作完成')), 'success');
                self.pollStatus();
            }
        }).catch(function (e) {
            ui.hideModal();
            ui.addNotification(null, E('p', _('操作失败: ') + e.message), 'error');
        });
    },

    render: function (data) {
        var self = this;
        var wgOutput = data[1].stdout || '';
        var accountExists = data[2] !== null;

        var isRunning = wgOutput.indexOf('interface: warp') !== -1;
        var hasHandshake = wgOutput.indexOf('latest handshake') !== -1;

        var ipv4 = uci.get('warp', 'config', 'address_v4') || '-';
        var ipv6 = uci.get('warp', 'config', 'address_v6') || '-';

        poll.add(L.bind(this.pollStatus, this), 5);

        var view = E('div', { 'class': 'cbi-map' }, [
            E('style', {}, [
                '.warp-header { background: linear-gradient(135deg, #f48120 0%, #faae2b 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }',
                '.warp-header h2 { margin: 0; }',
                '.warp-header p { margin: 5px 0 0 0; opacity: 0.9; }',
                '.status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 15px; margin-bottom: 20px; }',
                '.status-card { background: #fff; border-radius: 8px; padding: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }',
                '.status-card h4 { margin: 0 0 10px 0; border-bottom: 2px solid #f48120; padding-bottom: 8px; }',
                '.status-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }',
                '.status-row:last-child { border-bottom: none; }',
                '.badge { padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: bold; }',
                '.badge.success { background: #d4edda; color: #155724; }',
                '.badge.error { background: #f8d7da; color: #721c24; }',
                '.badge.warning { background: #fff3cd; color: #856404; }',
                '.action-buttons { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 15px; }',
                '.action-buttons .btn { padding: 10px 20px; }'
            ].join('\n')),

            E('div', { 'class': 'warp-header' }, [
                E('h2', {}, 'Cloudflare WARP'),
                E('p', {}, _('加密您的网络流量，提供更快、更安全的互联网访问'))
            ]),

            E('div', { 'class': 'status-grid' }, [
                E('div', { 'class': 'status-card' }, [
                    E('h4', {}, '🔌 ' + _('连接状态')),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, _('服务状态')),
                        E('span', { 'id': 'warp-status' },
                            isRunning ? E('span', { 'class': 'badge success' }, _('运行中'))
                                : E('span', { 'class': 'badge error' }, _('已停止')))
                    ]),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, _('连接状态')),
                        E('span', { 'id': 'warp-connection' },
                            hasHandshake ? E('span', { 'class': 'badge success' }, _('已连接'))
                                : (isRunning ? E('span', { 'class': 'badge warning' }, _('连接中...'))
                                    : E('span', { 'class': 'badge error' }, _('未连接'))))
                    ]),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, _('最后握手')),
                        E('span', { 'id': 'warp-handshake' }, '-')
                    ])
                ]),

                E('div', { 'class': 'status-card' }, [
                    E('h4', {}, '📊 ' + _('流量统计')),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, _('传输')),
                        E('span', { 'id': 'warp-transfer' }, '-')
                    ])
                ]),

                E('div', { 'class': 'status-card' }, [
                    E('h4', {}, '🌐 ' + _('账户信息')),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, _('注册状态')),
                        E('span', { 'id': 'warp-account' },
                            accountExists ? E('span', { 'class': 'badge success' }, _('已注册'))
                                : E('span', { 'class': 'badge warning' }, _('未注册')))
                    ]),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, 'IPv4'),
                        E('span', {}, ipv4)
                    ]),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, 'IPv6'),
                        E('span', { 'style': 'font-size: 11px;' }, ipv6)
                    ])
                ]),

                E('div', { 'class': 'status-card' }, [
                    E('h4', {}, '🧦 ' + _('SOCKS5 代理')),
                    E('div', { 'class': 'status-row' }, [
                        E('span', {}, _('代理状态')),
                        E('span', { 'id': 'warp-socks' }, E('span', { 'class': 'badge warning' }, _('检查中...')))
                    ])
                ])
            ]),

            E('div', { 'class': 'cbi-section' }, [
                E('h3', {}, '⚙️ ' + _('操作')),
                E('div', { 'class': 'action-buttons' }, [
                    E('button', {
                        'class': 'btn cbi-button cbi-button-action',
                        'click': L.bind(this.handleAction, this, 'register')
                    }, '📝 ' + _('注册账户')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-apply',
                        'click': L.bind(this.handleAction, this, 'start')
                    }, '▶️ ' + _('启动')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-remove',
                        'click': L.bind(this.handleAction, this, 'stop')
                    }, '⏹️ ' + _('停止')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-action',
                        'click': L.bind(this.handleAction, this, 'restart')
                    }, '🔄 ' + _('重启')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-neutral',
                        'click': L.bind(this.handleAction, this, 'test')
                    }, '🧪 ' + _('测试连接')),
                    E('button', {
                        'class': 'btn cbi-button cbi-button-remove',
                        'click': L.bind(this.handleAction, this, 'reset')
                    }, '🗑️ ' + _('重置账户'))
                ])
            ])
        ]);

        this.pollStatus();

        return view;
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
