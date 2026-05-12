#include "ofxGgmlAudio.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <iostream>
#include <string>

namespace {
	std::string toLower(std::string value) {
		std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
			return static_cast<char>(std::tolower(ch));
		});
		return value;
	}

	void printUsage() {
		std::cerr << "usage: audio_chunked_smoke <model.bin> <audio.wav> [expected text]\n";
	}
}

int main(int argc, char ** argv) {
	if (argc < 3 || argc > 4) {
		printUsage();
		return 2;
	}

	const std::string modelPath = argv[1];
	const std::string audioPath = argv[2];
	const std::string expectedText = argc >= 4 ? argv[3] : "";

	ofxGgmlAudioFrame frame;
	ofxGgmlAudioWavInfo info;
	std::string wavError;
	if (!ofxGgmlAudioUtils::loadWavFile(audioPath, frame, &info, &wavError)) {
		std::cerr << "could not load WAV: " << wavError << "\n";
		return 1;
	}

	ofxGgmlAudioStreamChunkerSettings chunkSettings;
	chunkSettings.format = frame.format;
	chunkSettings.windowSeconds = 6.0;
	chunkSettings.hopSeconds = 4.0;
	chunkSettings.maxBufferedSeconds = 30.0;

	ofxGgmlAudioStreamChunker chunker;
	if (!chunker.setup(chunkSettings)) {
		std::cerr << "could not configure stream chunker\n";
		return 1;
	}
	chunker.pushSamples(frame.samples, frame.timestampSeconds);

	ofxGgmlAudioWhisperBackend backend;
	if (!backend.isAvailable()) {
		std::cerr << "whisper.cpp backend is not available in this build\n";
		return 1;
	}

	ofxGgmlAudioWhisperSettings settings;
	settings.modelPath = modelPath;
	settings.language = "en";
	settings.timestamps = true;
	settings.threads = 0;
	const auto setupResult = backend.setup(settings);
	if (!setupResult) {
		std::cerr << "setup failed: " << setupResult.error << "\n";
		return 1;
	}

	ofxGgmlAudioRollingTranscript rolling;
	ofxGgmlAudioStreamRequest chunk;
	int chunkCount = 0;
	while (chunker.popNext(chunk, ofxGgmlAudioTask::Transcription)) {
		const auto result = backend.transcribe(chunk);
		if (!result) {
			std::cerr << "chunk transcription failed: " << result.error << "\n";
			return 1;
		}
		rolling.addResult(result);
		++chunkCount;
	}

	if (chunkCount < 2) {
		std::cerr << "chunked smoke expected at least two chunks\n";
		return 1;
	}
	if (rolling.empty()) {
		std::cerr << "chunked transcription produced no rolling segments\n";
		return 1;
	}

	const auto text = rolling.getText();
	const auto srt = rolling.buildSrt();
	const auto webVtt = rolling.buildWebVtt();
	if (text.empty() ||
		srt.find("-->") == std::string::npos ||
		webVtt.find("WEBVTT") != 0 ||
		webVtt.find("-->") == std::string::npos) {
		std::cerr << "rolling transcript did not produce text and subtitles\n";
		return 1;
	}
	if (!expectedText.empty() && toLower(text).find(toLower(expectedText)) == std::string::npos) {
		std::cerr << "chunked transcription did not contain expected text: " << expectedText << "\n";
		std::cerr << text << "\n";
		return 1;
	}

	const auto outputRoot = std::filesystem::temp_directory_path();
	const auto srtPath = outputRoot / "ofxGgmlAudio-whisper-chunked-smoke.srt";
	const auto vttPath = outputRoot / "ofxGgmlAudio-whisper-chunked-smoke.vtt";
	std::string subtitleError;
	if (!ofxGgmlAudioUtils::writeSrtFile(srtPath.string(), rolling.getSegments(), &subtitleError) ||
		!ofxGgmlAudioUtils::writeWebVttFile(vttPath.string(), rolling.getSegments(), &subtitleError) ||
		!std::filesystem::exists(srtPath) ||
		!std::filesystem::exists(vttPath)) {
		std::cerr << "could not write rolling subtitle files: " << subtitleError << "\n";
		return 1;
	}
	std::filesystem::remove(srtPath);
	std::filesystem::remove(vttPath);

	std::cout << text << "\n";
	return 0;
}
