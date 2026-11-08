package io.emergy.androiddns;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.LinkProperties;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import org.json.JSONArray;
import org.json.JSONObject;
import java.net.InetAddress;

final class NetworkSnapshot {
    static JSONObject capture(Context context) throws Exception {
        ConnectivityManager manager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        Network network = manager.getActiveNetwork();
        LinkProperties properties = network == null ? null : manager.getLinkProperties(network);
        JSONObject result = new JSONObject();
        result.put("version", 1);
        result.put("captured_at_ms", System.currentTimeMillis());
        result.put("connected", properties != null);
        JSONArray servers = new JSONArray();
        if (properties != null) {
            for (InetAddress server : properties.getDnsServers()) servers.put(server.getHostAddress());
        }
        result.put("dns_servers", servers);
        result.put("domains", properties == null ? JSONObject.NULL : properties.getDomains());
        result.put("interface", properties == null ? JSONObject.NULL : properties.getInterfaceName());
        boolean privateDns = properties != null && Build.VERSION.SDK_INT >= 28 && properties.isPrivateDnsActive();
        result.put("private_dns_active", privateDns);
        result.put("private_dns_name", privateDns ? properties.getPrivateDnsServerName() : JSONObject.NULL);
        NetworkCapabilities capabilities = network == null ? null : manager.getNetworkCapabilities(network);
        result.put("vpn", capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN));
        return result;
    }
}
