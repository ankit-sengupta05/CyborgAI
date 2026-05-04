package com.ankit.cyborg

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ankit.cyborg/lightrt"
    private val EVENT_CHANNEL = "com.ankit.cyborg/lightrt_events"

    private var llmInference: LlmInference? = null
    private var eventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.IO + Job())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init_lightrt" -> {
                    val modelPath = call.argument<String>("modelPath") ?: return@setMethodCallHandler result.error("INVALID_ARG", "modelPath required", null)

                    scope.launch {
                        try {
                            val optionsBuilder = LlmInference.LlmInferenceOptions.builder()
                                .setModelPath(modelPath)
                                .setMaxTokens(1024)

                            llmInference?.close()
                            llmInference = LlmInference.createFromOptions(context, optionsBuilder.build())
                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("INIT_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "generate_lightrt" -> {
                    val prompt = call.argument<String>("prompt") ?: return@setMethodCallHandler result.error("INVALID_ARG", "prompt required", null)
                    val llm = llmInference

                    if (llm == null) {
                        result.error("NOT_INITIALIZED", "LightRT not initialized", null)
                        return@setMethodCallHandler
                    }

                    // For MediaPipe GenAI 0.10.33+, generateResponseAsync takes the ProgressListener directly
                    try {
                        llm.generateResponseAsync(prompt) { partialResult, done ->
                            scope.launch(Dispatchers.Main) {
                                if (partialResult != null) {
                                    eventSink?.success(partialResult)
                                }
                                if (done) {
                                    eventSink?.success("[DONE]")
                                }
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GEN_FAILED", e.message, null)
                    }
                }
                "unload_lightrt" -> {
                    llmInference?.close()
                    llmInference = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        llmInference?.close()
        scope.cancel()
    }
}
