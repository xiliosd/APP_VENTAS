package com.appventas.app_ventas

import android.os.Build
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: la necesita local_auth para mostrar el diálogo de huella.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // El dictado solo se permite si Android reconoce la voz dentro del
        // celular; si no, speech_to_text usaría el servicio en línea.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vecitienda/voz")
            .setMethodCallHandler { llamada, resultado ->
                if (llamada.method == "hayReconocimientoLocal") {
                    resultado.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    )
                } else {
                    resultado.notImplemented()
                }
            }
    }
}
