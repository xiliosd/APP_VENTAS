package com.appventas.app_ventas

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val PEDIDO_MICROFONO = 7301

// FragmentActivity: la necesita local_auth para mostrar el diálogo de huella.
class MainActivity : FlutterFragmentActivity() {
    private var dictado: DictadoLocal? = null
    private var permisoPendiente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vecitienda/voz")
        // El dictado solo se permite si Android reconoce la voz dentro del
        // celular; si no, el audio iría a un servicio en línea.
        canal.setMethodCallHandler { llamada, resultado ->
            when (llamada.method) {
                "hayReconocimientoLocal" -> resultado.success(hayReconocimientoLocal())
                "idiomasDescargados" -> responderIdiomasDescargados(resultado)
                "pedirPermiso" -> pedirPermiso(resultado)
                "escuchar" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    ) {
                        dictadoCon(canal).escuchar(
                            llamada.argument<String>("idioma"),
                            llamada.argument<Int>("silencioMs") ?: 3000,
                        )
                        resultado.success(null)
                    } else {
                        resultado.error("sin_dictado_local", null, null)
                    }
                }
                "detener" -> {
                    dictado?.detener()
                    resultado.success(null)
                }
                else -> resultado.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        dictado?.soltar()
        super.onDestroy()
    }

    private fun hayReconocimientoLocal() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    @RequiresApi(Build.VERSION_CODES.S)
    private fun dictadoCon(canal: MethodChannel): DictadoLocal =
        dictado ?: DictadoLocal(this, canal).also { dictado = it }

    private fun pedirPermiso(resultado: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            resultado.success(true)
            return
        }
        permisoPendiente?.success(false)
        permisoPendiente = resultado
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PEDIDO_MICROFONO,
        )
    }

    override fun onRequestPermissionsResult(
        codigo: Int,
        permisos: Array<out String>,
        respuestas: IntArray,
    ) {
        super.onRequestPermissionsResult(codigo, permisos, respuestas)
        if (codigo != PEDIDO_MICROFONO) return
        permisoPendiente?.success(
            respuestas.firstOrNull() == PackageManager.PERMISSION_GRANTED
        )
        permisoPendiente = null
    }

    // Android lista como soportados idiomas que no están descargados; pedir uno
    // de esos corta la escucha. Antes de Android 13 no se puede saber: null.
    private fun responderIdiomasDescargados(resultado: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
        ) {
            resultado.success(null)
            return
        }
        val principal = Handler(Looper.getMainLooper())
        val reconocedor = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        var respondido = false
        fun responder(idiomas: List<String>?) {
            principal.post {
                if (respondido) return@post
                respondido = true
                reconocedor.destroy()
                resultado.success(idiomas)
            }
        }
        reconocedor.checkRecognitionSupport(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH),
            { it.run() },
            object : RecognitionSupportCallback {
                override fun onSupportResult(soporte: RecognitionSupport) {
                    responder(soporte.installedOnDeviceLanguages)
                }

                override fun onError(error: Int) {
                    responder(null)
                }
            }
        )
    }
}
