package io.github.nithium27.otis;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.ByteArrayInputStream;
import java.io.IOException;

/**
 * Shows the Otis alerts page (bundled in assets/) in a WebView. The page is served from an https
 * address that never reaches the network, so the browser's encryption (WebCrypto) is allowed.
 */
public class MainActivity extends Activity {
    static final String HOST = "appassets.androidplatform.net";    // reserved by Android for app assets

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        WebView web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);                  // localStorage keeps the phone key, inside this app only
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        web.setWebChromeClient(new WebChromeClient()); // lets the page ask "Remove the key?"
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                Uri url = req.getUrl();
                if (!HOST.equals(url.getHost())) {
                    return null;                       // ntfy: a normal network request
                }
                String path = url.getPath();
                path = (path == null || path.equals("/")) ? "index.html" : path.substring(1);
                try {
                    if (path.contains("..")) {
                        throw new IOException("bad path");
                    }
                    return new WebResourceResponse(mime(path), "utf-8", getAssets().open(path));
                } catch (IOException e) {
                    return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", null,
                            new ByteArrayInputStream(new byte[0]));
                }
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                if (HOST.equals(req.getUrl().getHost())) {
                    return false;
                }
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, req.getUrl()));   // other links: the browser
                } catch (ActivityNotFoundException e) {
                    // nothing can open it; stay on the page
                }
                return true;
            }
        });
        setContentView(web);
        web.loadUrl("https://" + HOST + "/");
    }

    static String mime(String path) {
        if (path.endsWith(".html")) return "text/html";
        if (path.endsWith(".png")) return "image/png";
        if (path.endsWith(".webmanifest")) return "application/manifest+json";
        return "application/octet-stream";
    }
}
