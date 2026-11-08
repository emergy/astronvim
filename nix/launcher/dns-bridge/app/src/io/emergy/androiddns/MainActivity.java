package io.emergy.androiddns;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

public final class MainActivity extends Activity {
    private TextView status;
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        int padding = (int) (20 * getResources().getDisplayMetrics().density);
        content.setPadding(padding, padding, padding, padding);
        TextView description = new TextView(this);
        description.setText("DNS активной сети Android\n\nПомощник для Nix и Termux. Работает по запросу, без root, отладки и фонового сервиса. Сам настройки DNS не меняет.\n\nЕсли VPN выбирает приложения отдельно, включите этот помощник в тот же список, что и Launcher.\n");
        content.addView(description);
        Button refresh = new Button(this);
        refresh.setText("Обновить сведения");
        refresh.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View view) { refresh(); }
        });
        content.addView(refresh);
        status = new TextView(this);
        status.setTextIsSelectable(true);
        content.addView(status);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        setContentView(scroll);
        refresh();
    }
    private void refresh() {
        try { status.setText(NetworkSnapshot.capture(this).toString(2)); }
        catch (Exception error) { status.setText("Ошибка: " + error.getClass().getSimpleName()); }
    }
}
