var ExtensionPreprocessingJS = {
    run: function (arguments) {
        var scripts = [];
        var size = 0;
        document.querySelectorAll('script[type="application/ld+json"]').forEach(function (node) {
            var text = node.textContent || '';
            if (scripts.length < 40 && size + text.length < 200000) {
                scripts.push(text);
                size += text.length;
            }
        });
        arguments.completionFunction({ url: window.location.href, jsonLD: scripts });
    }
};
