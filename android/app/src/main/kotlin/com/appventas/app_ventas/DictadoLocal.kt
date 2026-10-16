package com.appventas.app_ventas

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel

// Dictado con el reconocedor de voz dentro del celular: el audio no sale del
// teléfono. Cada dictado usa un reconocedor nuevo y lo destruye al terminar;
// si queda vivo, el siguiente choca con su sesión y falla al instante.
@RequiresApi(Build.VERSION_CODES.S)
class DictadoLocal(
    private val contexto: Context,
    private val canal: MethodChannel,
) {
    private var reconocedor: SpeechRecognizer? = null

    fun escuchar(idioma: String?, silencioMs: Int) {
        soltar()
        val nuevo = SpeechRecognizer.createOnDeviceSpeechRecognizer(contexto)
        reconocedor = nuevo
        nuevo.setRecognitionListener(Oyente(nuevo))
        nuevo.startListening(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, contexto.packageName)
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                    silencioMs,
                )
                if (idioma != null) putExtra(RecognizerIntent.EXTRA_LANGUAGE, idioma)
            }
        )
    }

    // Deja de oír; el reconocedor aún entrega lo final y después se destruye.
    fun detener() {
        reconocedor?.stopListening()
    }

    fun soltar() {
        reconocedor?.let {
            it.cancel()
            it.destroy()
        }
        reconocedor = null
    }

    // Un oyente por reconocedor: lo que llegue de uno ya soltado se ignora.
    private inner class Oyente(private val propio: SpeechRecognizer) : RecognitionListener {
        private val vigente get() = reconocedor === propio

        override fun onPartialResults(resultados: Bundle?) {
            if (vigente) canal.invokeMethod("parcial", primerTexto(resultados))
        }

        override fun onResults(resultados: Bundle?) {
            if (!vigente) return
            canal.invokeMethod("final", primerTexto(resultados))
            soltar()
        }

        override fun onError(error: Int) {
            if (!vigente) return
            canal.invokeMethod("error", error)
            soltar()
        }

        override fun onReadyForSpeech(parametros: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(nivel: Float) {}
        override fun onBufferReceived(audio: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(tipo: Int, parametros: Bundle?) {}
    }

    private fun primerTexto(resultados: Bundle?): String =
        resultados
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?: ""
}
