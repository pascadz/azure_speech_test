import { useEffect, useRef, useState } from "react";
import { Mic, MicOff, Trash2 } from "lucide-react";
import { useTranslation } from "react-i18next";

import { Button } from "@/components/ui/button";
import StatusMessage from "@/components/ui/status-message";

import useRealTime from "@/hooks/useRealtime";
import useAudioRecorder from "@/hooks/useAudioRecorder";
import useAudioPlayer from "@/hooks/useAudioPlayer";

import logo from "./assets/logo.svg";

type ChatEntry = {
    role: "user" | "assistant";
    text: string;
    final: boolean; // true = Transkription/Antwort ist komplett
};

function App() {
    const [isRecording, setIsRecording] = useState(false);
    const [chatHistory, setChatHistory] = useState<ChatEntry[]>([]);
    const chatEndRef = useRef<HTMLDivElement>(null);

    // Auto-Scroll zum neuesten Eintrag
    useEffect(() => {
        chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [chatHistory]);

    const { startSession, addUserAudio, inputAudioBufferClear } = useRealTime({
        enableInputAudioTranscription: true,

        onWebSocketOpen: () => console.log("WebSocket connection opened"),
        onWebSocketClose: () => console.log("WebSocket connection closed"),
        onWebSocketError: event => console.error("WebSocket error:", event),
        onReceivedError: message => console.error("error", message),

        onReceivedResponseAudioDelta: message => {
            isRecording && playAudio(message.delta);
        },

        onReceivedInputAudioBufferSpeechStarted: () => {
            stopAudioPlayer();
        },

        // ── User-Sprache transkribiert (Whisper, kommt nach dem Sprechen) ──
        onReceivedInputAudioTranscriptionCompleted: message => {
            const text = message.transcript?.trim();
            if (text) {
                setChatHistory(prev => [...prev, { role: "user", text, final: true }]);
            }
        },

        // ── KI-Antwort als Text (Streaming, Wort für Wort) ──
        onReceivedResponseAudioTranscriptDelta: message => {
            setChatHistory(prev => {
                const last = prev[prev.length - 1];
                if (last && last.role === "assistant" && !last.final) {
                    // Letzten assistant-Eintrag erweitern (Streaming)
                    const updated = [...prev];
                    updated[updated.length - 1] = {
                        ...last,
                        text: last.text + message.delta
                    };
                    return updated;
                }
                // Neuen assistant-Eintrag starten
                return [...prev, { role: "assistant", text: message.delta, final: false }];
            });
        },

        // ── KI-Antwort komplett ──
        onReceivedResponseDone: () => {
            setChatHistory(prev => {
                const last = prev[prev.length - 1];
                if (last && last.role === "assistant" && !last.final) {
                    const updated = [...prev];
                    updated[updated.length - 1] = { ...last, final: true };
                    return updated;
                }
                return prev;
            });
        }
    });

    const { reset: resetAudioPlayer, play: playAudio, stop: stopAudioPlayer } = useAudioPlayer();
    const { start: startAudioRecording, stop: stopAudioRecording } = useAudioRecorder({ onAudioRecorded: addUserAudio });

    const onToggleListening = async () => {
        if (!isRecording) {
            startSession();
            await startAudioRecording();
            resetAudioPlayer();
            setIsRecording(true);
        } else {
            await stopAudioRecording();
            stopAudioPlayer();
            inputAudioBufferClear();
            setIsRecording(false);
        }
    };

    const { t } = useTranslation();

    return (
        <div className="flex min-h-screen flex-col bg-gray-100 text-gray-900">
            <div className="p-4 sm:absolute sm:left-4 sm:top-4">
                <img src={logo} alt="Azure logo" className="h-16 w-16" />
            </div>
            <main className="flex flex-grow flex-col items-center justify-center px-4">
                <h1 className="mb-4 bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-4xl font-bold text-transparent md:text-7xl">
                    {t("app.title")}
                </h1>

                {/* ── Chat-Verlauf ── */}
                <div className="mb-4 w-full max-w-2xl rounded-xl border border-gray-200 bg-white shadow-sm">
                    <div className="flex items-center justify-between border-b border-gray-100 px-4 py-2">
                        <span className="text-sm font-medium text-gray-500">{t("history.answerHistory")}</span>
                        {chatHistory.length > 0 && (
                            <button
                                onClick={() => setChatHistory([])}
                                className="text-gray-400 hover:text-red-500 transition-colors"
                                title={t("history.clear")}
                            >
                                <Trash2 className="h-4 w-4" />
                            </button>
                        )}
                    </div>
                    <div className="max-h-96 overflow-y-auto p-4 space-y-3">
                        {chatHistory.length === 0 ? (
                            <p className="text-center text-sm text-gray-400 py-8">{t("history.noHistory")}</p>
                        ) : (
                            chatHistory.map((entry, i) => (
                                <div
                                    key={i}
                                    className={`flex ${entry.role === "user" ? "justify-end" : "justify-start"}`}
                                >
                                    <div
                                        className={`max-w-[80%] rounded-2xl px-4 py-2 text-sm leading-relaxed ${
                                            entry.role === "user"
                                                ? "bg-purple-500 text-white rounded-br-md"
                                                : "bg-gray-100 text-gray-800 rounded-bl-md"
                                        } ${!entry.final ? "opacity-70" : ""}`}
                                    >
                                        {entry.role === "assistant" && (
                                            <span className="mb-1 block text-xs font-semibold text-purple-600">KI</span>
                                        )}
                                        {entry.text}
                                        {!entry.final && (
                                            <span className="ml-1 inline-block animate-pulse">▍</span>
                                        )}
                                    </div>
                                </div>
                            ))
                        )}
                        <div ref={chatEndRef} />
                    </div>
                </div>

                {/* ── Mikrofon-Button ── */}
                <div className="mb-4 flex flex-col items-center justify-center">
                    <Button
                        onClick={onToggleListening}
                        className={`h-12 w-60 ${isRecording ? "bg-red-600 hover:bg-red-700" : "bg-purple-500 hover:bg-purple-600"}`}
                        aria-label={isRecording ? t("app.stopRecording") : t("app.startRecording")}
                    >
                        {isRecording ? (
                            <>
                                <MicOff className="mr-2 h-4 w-4" />
                                {t("app.stopConversation")}
                            </>
                        ) : (
                            <>
                                <Mic className="mr-2 h-6 w-6" />
                            </>
                        )}
                    </Button>
                    <StatusMessage isRecording={isRecording} />
                </div>
            </main>

            <footer className="py-4 text-center">
                <p>{t("app.footer")}</p>
            </footer>
        </div>
    );
}

export default App;
