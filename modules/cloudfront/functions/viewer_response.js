function handler(event) {
    var response = event.response;
    var request = event.request;
    var uri = request.uri.toLowerCase();
    var staticExt = ["css", "js", "webp", "woff2"];

    try {
        // 1y cache-control header to static assets
        if (uri.includes(".") && staticExt.includes(uri.split(".")[uri.split(".").length - 1])) {
            response.headers['cache-control'] = {value: 'public, max-age=31536000'};
        }
    }
    catch (e) {        
        console.log(e);
    }

    return response;
}
