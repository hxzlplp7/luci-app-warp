'use strict';
'require view';
'require fs';
'require ui';
'require poll';

return view.extend({
    load: function() {
        return Promise.all([
            L.resolveDefault(fs.exec('/usr/bin/logread', ['-e', 'warp']), { stdout: '' })
        ]);
    },

    render: function(data) {
        var logData = data[0].stdout || _('No log data available');
        
        var logTextarea = E('textarea', {
            'id': 'syslog',
            'class': 'cbi-input-textarea',
            'style': 'width: 100%; height: 500px; font-family: monospace; font-size: 12px; background: #1e1e1e; color: #d4d4d4; border-radius: 8px; padding: 15px;',
            'readonly': 'readonly',
            'wrap': 'off'
        }, [logData]);

        var autoRefreshCheckbox = E('input', {
            'id': 'auto-refresh',
            'type': 'checkbox',
            'checked': 'checked'
        });

        poll.add(L.bind(function() {
            var checkbox = document.getElementById('auto-refresh');
            if (checkbox && checkbox.checked) {
                return fs.exec('/usr/bin/logread', ['-e', 'warp']).then(function(res) {
                    var textarea = document.getElementById('syslog');
                    if (textarea) {
                        textarea.value = res.stdout || _('No log data available');
                        textarea.scrollTop = textarea.scrollHeight;
                    }
                });
            }
            return Promise.resolve();
        }, this), 5);

        return E('div', { 'class': 'cbi-map' }, [
            E('h2', {}, _('WARP 日志')),
            E('div', { 'class': 'cbi-section' }, [
                E('div', { 'style': 'display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;' }, [
                    E('span', {}, _('WARP 服务运行日志')),
                    E('div', { 'style': 'display: flex; gap: 15px; align-items: center;' }, [
                        E('label', { 'style': 'display: flex; align-items: center; gap: 5px;' }, [
                            autoRefreshCheckbox,
                            _('自动刷新')
                        ]),
                        E('button', {
                            'class': 'btn cbi-button cbi-button-action',
                            'click': function() {
                                return fs.exec('/usr/bin/logread', ['-e', 'warp']).then(function(res) {
                                    var textarea = document.getElementById('syslog');
                                    if (textarea) {
                                        textarea.value = res.stdout || _('No log data available');
                                        textarea.scrollTop = textarea.scrollHeight;
                                    }
                                });
                            }
                        }, _('刷新日志')),
                        E('button', {
                            'class': 'btn cbi-button cbi-button-neutral',
                            'click': function() {
                                var textarea = document.getElementById('syslog');
                                if (textarea) {
                                    textarea.value = _('Log display cleared');
                                }
                            }
                        }, _('清空显示'))
                    ])
                ]),
                logTextarea
            ])
        ]);
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
