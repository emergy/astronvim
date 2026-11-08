package io.emergy.androiddns;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

public final class NetworkReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (!"io.emergy.androiddns.GET_NETWORK".equals(intent.getAction())) {
            setResultCode(1);
            setResultData("Unsupported action");
            return;
        }
        try {
            JSONObject snapshot = NetworkSnapshot.capture(context);
            String encoded = Base64.encodeToString(snapshot.toString().getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP);
            setResultCode(0);
            setResultData("ANDROID_DNS_V1:" + encoded);
        } catch (Exception error) {
            setResultCode(1);
            setResultData("DNS query failed: " + error.getClass().getSimpleName());
        }
    }
}
