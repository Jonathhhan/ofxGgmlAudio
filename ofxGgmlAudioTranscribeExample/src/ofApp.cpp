#include "ofApp.h"

#include "imgui.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <vector>

namespace {
#ifndef OFXGGML_AUDIO_EXAMPLE_LOG_MODULE
#define OFXGGML_AUDIO_EXAMPLE_LOG_MODULE "ofxGgmlAudioTranscribeExample"
#endif
#ifndef OFXGGML_AUDIO_EXAMPLE_WINDOW_TITLE
#define OFXGGML_AUDIO_EXAMPLE_WINDOW_TITLE "ofxGgmlAudio transcribe example"
#endif
#ifndef OFXGGML_AUDIO_EXAMPLE_PANEL_TITLE
#define OFXGGML_AUDIO_EXAMPLE_PANEL_TITLE "ofxGgmlAudio Transcribe Example"
#endif
	constexpr const char * LogModule = OFXGGML_AUDIO_EXAMPLE_LOG_MODULE;
	constexpr const char * WindowTitle = OFXGGML_AUDIO_EXAMPLE_WINDOW_TITLE;
	constexpr const char * PanelTitle = OFXGGML_AUDIO_EXAMPLE_PANEL_TITLE;

	std::string envValue(const char * name) {
		const char * value = std::getenv(name);
		return value ? std::string(value) : std::string();
	}

	std::string trimText(const std::string & value) {
		const auto first = value.find_first_not_of(" \t\r\n");
		if (first == std::string::npos) {
			return {};
		}
		const auto last = value.find_last_not_of(" \t\r\n");
		return value.substr(first, (last - first) + 1);
	}

	std::string lowerText(const std::string & value) {
		std::string lowered = value;
		std::transform(lowered.begin(), lowered.end(), lowered.begin(), [](unsigned char c) {
			return static_cast<char>(std::tolower(c));
		});
		return lowered;
	}

	bool isAutoLanguage(const std::string & value) {
		return lowerText(value) == "auto";
	}

	bool isEnabledFlag(const std::string & value) {
		const auto lowered = lowerText(trimText(value));
		return lowered == "1" || lowered == "true" || lowered == "on" || lowered == "yes";
	}

	bool isDisabledFlag(const std::string & value) {
		const auto lowered = lowerText(trimText(value));
		return lowered == "0" || lowered == "false" || lowered == "off" || lowered == "no";
	}

	std::string normalizePath(const std::filesystem::path & path) {
		return path.lexically_normal().string();
	}

	ImVec2 fitWindowSize(float preferredWidth, float preferredHeight) {
		const ImVec2 display = ImGui::GetIO().DisplaySize;
		const float availableWidth = std::max(420.0f, display.x - 32.0f);
		const float availableHeight = std::max(360.0f, display.y - 32.0f);
		return ImVec2(
			std::min(preferredWidth, availableWidth),
			std::min(preferredHeight, availableHeight));
	}

	std::string makeOutputText(
		const std::string & text,
		std::size_t segmentCount,
		const std::string & summary = {}) {
		std::string output = text.empty() ? std::string("(none)") : text;
		if (segmentCount > 0) {
			output += "\n\nsegments: " + ofToString(segmentCount);
		}
		if (!summary.empty()) {
			output += "\n" + summary;
		}
		return output;
	}

	std::string writeSubtitleFiles(
		const std::string & audioPathText,
		const std::vector<ofxGgmlAudioTranscriptSegment> & segments) {
		if (segments.empty()) {
			return "Transcription complete; no timestamped segments returned";
		}

		const std::filesystem::path audioPath(audioPathText);
		const auto outputRoot = audioPath.has_parent_path()
			? audioPath.parent_path()
			: std::filesystem::current_path();
		const auto srtPath = outputRoot / (audioPath.stem().string() + ".srt");
		const auto vttPath = outputRoot / (audioPath.stem().string() + ".vtt");
		std::string subtitleError;
		const bool wroteSrt = ofxGgmlAudioUtils::writeSrtFile(
			srtPath.string(),
			segments,
			&subtitleError);
		const bool wroteVtt = ofxGgmlAudioUtils::writeWebVttFile(
			vttPath.string(),
			segments,
			&subtitleError);
		if (wroteSrt && wroteVtt) {
			ofLogNotice(LogModule)
				<< "wrote subtitles: " << srtPath.string() << " and " << vttPath.string();
			return "Transcription complete; subtitles written next to the audio file";
		}

		ofLogWarning(LogModule) << subtitleError;
		return "Transcription complete; subtitle export failed: " + subtitleError;
	}
}

void ofApp::setup() {
	ofSetWindowTitle(WindowTitle);
	gui.setup();

	const auto modelFromEnv = trimText(envValue("OFXGGML_AUDIO_MODEL"));
	const auto audioFromEnv = trimText(envValue("OFXGGML_AUDIO_FILE"));
	const auto languageFromEnv = trimText(envValue("OFXGGML_AUDIO_LANGUAGE"));
	const auto threadsFromEnv = trimText(envValue("OFXGGML_AUDIO_THREADS"));
	const auto translateFromEnv = trimText(envValue("OFXGGML_AUDIO_TRANSLATE"));
	const auto timestampsFromEnv = trimText(envValue("OFXGGML_AUDIO_TIMESTAMPS"));
	copyToBuffer(modelPathBuffer, !modelFromEnv.empty() ? modelFromEnv : findFirstFile(
		{ "models", "../models", "../../models", "bin/data/models", "bin/data" },
		{ ".bin", ".gguf" }));
	copyToBuffer(audioPathBuffer, !audioFromEnv.empty() ? audioFromEnv : findFirstFile(
		{ "audio", "data", "bin/data", "bin/data/audio", "models", "../models" },
		{ ".wav" }));
	copyToBuffer(languageBuffer, !languageFromEnv.empty() ? languageFromEnv : "auto");
	if (!threadsFromEnv.empty()) {
		threads = ofClamp(ofToInt(threadsFromEnv), 0, 32);
	}
	translate = isEnabledFlag(translateFromEnv);
	if (!timestampsFromEnv.empty()) {
		timestamps = !isDisabledFlag(timestampsFromEnv);
	}

	status = "idle";
	detail = backend.isAvailable()
		? "whisper.cpp native backend is available"
		: "native backend disabled; run scripts/build-whisper.* and compile with OFXGGMLAUDIO_WITH_WHISPER";
	ofLogNotice(LogModule) << detail;
}

void ofApp::keyPressed(int key) {
	if (key == 'r' || key == 'R') {
		startTranscription();
	}
}

void ofApp::exit() {
	if (worker.joinable()) {
		worker.join();
	}
}

void ofApp::draw() {
	ofBackground(18);
	const bool isRunning = running.load();
	std::string statusSnapshot;
	std::string detailSnapshot;
	std::string outputSnapshot;
	std::string rollingSummarySnapshot;
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		statusSnapshot = status;
		detailSnapshot = detail;
		outputSnapshot = output;
		rollingSummarySnapshot = rollingSummary;
	}

	gui.begin();

	ImGui::SetNextWindowPos(ImVec2(16.0f, 16.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(fitWindowSize(920.0f, 620.0f), ImGuiCond_Once);
	ImGui::Begin(PanelTitle);

	const bool canEdit = !isRunning;
	if (!canEdit) {
		ImGui::BeginDisabled();
	}
	ImGui::InputText("Model", modelPathBuffer.data(), modelPathBuffer.size());
	ImGui::InputText("Audio", audioPathBuffer.data(), audioPathBuffer.size());
	ImGui::InputText("Language", languageBuffer.data(), languageBuffer.size());
	ImGui::SliderInt("Threads", &threads, 0, 32);
	ImGui::Checkbox("Translate", &translate);
	ImGui::SameLine();
	ImGui::Checkbox("Timestamps", &timestamps);
	ImGui::Checkbox("Chunked rolling transcript", &chunkedMode);
	if (chunkedMode) {
		ImGui::SliderFloat("Window seconds", &chunkWindowSeconds, 1.0f, 30.0f, "%.1f");
		ImGui::SliderFloat("Hop seconds", &chunkHopSeconds, 0.5f, 30.0f, "%.1f");
		if (chunkHopSeconds > chunkWindowSeconds) {
			chunkHopSeconds = chunkWindowSeconds;
		}
	}
	if (!canEdit) {
		ImGui::EndDisabled();
	}

	if (isRunning) {
		if (ImGui::Button("Cancel")) {
			cancelRequested.store(true);
			setStatus("cancelling", "Finishing the current chunk before stopping");
		}
	} else {
		if (ImGui::Button("Run")) {
			startTranscription();
		}
	}
	ImGui::SameLine();
	ImGui::TextUnformatted(isRunning ? "running" : statusSnapshot.c_str());

	ImGui::SeparatorText("Status");
	ImGui::TextWrapped("%s", detailSnapshot.c_str());
	if (!rollingSummarySnapshot.empty()) {
		ImGui::TextWrapped("%s", rollingSummarySnapshot.c_str());
	}
	ImGui::SeparatorText("Output");
	ImGui::BeginChild("output", ImVec2(0, 260), true, ImGuiWindowFlags_HorizontalScrollbar);
	ImGui::TextWrapped("%s", outputSnapshot.empty() ? "(none)" : outputSnapshot.c_str());
	ImGui::EndChild();

	ImGui::End();
	gui.end();
}

void ofApp::startTranscription() {
	if (running.load()) {
		return;
	}
	if (worker.joinable()) {
		worker.join();
	}

	settings.modelPath = trimText(modelPathBuffer.data());
	settings.threads = threads;
	settings.translate = translate;
	settings.timestamps = timestamps;
	settings.language = trimText(languageBuffer.data());
	if (isAutoLanguage(settings.language)) {
		settings.language.clear();
	}
	request.audioPath = trimText(audioPathBuffer.data());
	request.language = settings.language;
	copyToBuffer(modelPathBuffer, settings.modelPath);
	copyToBuffer(audioPathBuffer, request.audioPath);
	copyToBuffer(languageBuffer, settings.language.empty() ? "auto" : settings.language);

	{
		std::lock_guard<std::mutex> lock(stateMutex);
		status = "running";
		detail = (chunkedMode ? "Chunked transcription: " : "Transcribing ") + request.audioPath;
		output.clear();
		rollingSummary.clear();
		result = ofxGgmlAudioResult {};
	}
	cancelRequested.store(false);
	running.store(true);
	ofLogNotice(LogModule)
		<< "model: " << settings.modelPath;
	ofLogNotice(LogModule)
		<< "audio: " << request.audioPath;
	ofLogNotice(LogModule)
		<< "mode: " << (chunkedMode ? "chunked" : "file");

	worker = std::thread(&ofApp::runWorker, this);
}

void ofApp::runWorker() {
	auto setupResult = backend.setup(settings);
	if (!setupResult) {
		ofLogWarning(LogModule) << setupResult.error;
		setStatus("setup failed", setupResult.error);
		return;
	}

	auto transcribeResult = chunkedMode ? runChunkedTranscription() : runFileTranscription();
	if (!transcribeResult) {
		if (cancelRequested.load()) {
			setStatus("cancelled", "Cancelled before transcript segments were produced");
			return;
		}
		ofLogWarning(LogModule) << transcribeResult.error;
		setStatus("transcription failed", transcribeResult.error);
		return;
	}

	ofLogNotice(LogModule) << transcribeResult.text;
	std::string nextDetail = writeSubtitleFiles(request.audioPath, transcribeResult.segments);
	const bool wasCancelled = cancelRequested.load();
	if (wasCancelled) {
		nextDetail = "Cancelled after current chunk; " + nextDetail;
	}
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		result = transcribeResult;
		output = makeOutputText(transcribeResult.text, transcribeResult.segments.size());
		status = wasCancelled ? "cancelled" : "complete";
		detail = nextDetail;
	}
	running.store(false);
}

ofxGgmlAudioResult ofApp::runFileTranscription() {
	return backend.transcribe(request);
}

ofxGgmlAudioResult ofApp::runChunkedTranscription() {
	ofxGgmlAudioFrame frame;
	ofxGgmlAudioWavInfo info;
	std::string wavError;
	if (!ofxGgmlAudioUtils::loadWavFile(request.audioPath, frame, &info, &wavError)) {
		ofxGgmlAudioResult error;
		error.error = "could not load WAV for chunked transcription: " + wavError;
		return error;
	}

	ofxGgmlAudioStreamChunkerSettings chunkSettings;
	const double audioDurationSeconds = frame.format.sampleRate > 0
		? static_cast<double>(frame.getFrameCount()) / static_cast<double>(frame.format.sampleRate)
		: 0.0;
	const double windowSeconds = audioDurationSeconds > 0.0
		? std::min<double>(std::max(1.0f, chunkWindowSeconds), audioDurationSeconds)
		: std::max(1.0f, chunkWindowSeconds);
	chunkSettings.format = frame.format;
	chunkSettings.windowSeconds = windowSeconds;
	chunkSettings.hopSeconds = std::max(0.5, std::min<double>(chunkHopSeconds, windowSeconds));
	chunkSettings.maxBufferedSeconds = std::max(chunkSettings.windowSeconds * 2.0, 60.0);

	ofxGgmlAudioStreamChunker chunker;
	if (!chunker.setup(chunkSettings)) {
		ofxGgmlAudioResult error;
		error.error = "could not configure audio stream chunker";
		return error;
	}
	chunker.pushSamples(frame.samples, frame.timestampSeconds);

	ofxGgmlAudioRollingTranscript rolling;
	ofxGgmlAudioStreamRequest chunk;
	int chunkCount = 0;
	int addedSegments = 0;
	while (chunker.popNext(chunk, ofxGgmlAudioTask::Transcription)) {
		if (cancelRequested.load()) {
			break;
		}
		++chunkCount;
		{
			std::lock_guard<std::mutex> lock(stateMutex);
			detail = "Transcribing chunk " + ofToString(chunkCount) +
				" at " + ofxGgmlAudioUtils::formatSubtitleTimestamp(chunk.timestampSeconds);
			rollingSummary = "chunks: " + ofToString(chunkCount) +
				", rolling segments: " + ofToString(rolling.size());
		}

		const auto chunkResult = backend.transcribe(chunk);
		if (!chunkResult) {
			return chunkResult;
		}

		addedSegments += rolling.addResult(chunkResult);
		const auto text = rolling.getText();
		{
			std::lock_guard<std::mutex> lock(stateMutex);
			output = makeOutputText(
				text,
				rolling.size(),
				"chunks: " + ofToString(chunkCount) +
					", added segments: " + ofToString(addedSegments));
			rollingSummary = "chunks: " + ofToString(chunkCount) +
				", rolling segments: " + ofToString(rolling.size()) +
				", added segments: " + ofToString(addedSegments);
		}
		ofLogNotice(LogModule)
			<< "chunk " << chunkCount << ": " << chunkResult.text;
	}

	ofxGgmlAudioResult finalResult;
	finalResult.success = !rolling.empty();
	finalResult.text = rolling.getText();
	finalResult.segments = rolling.getSegments();
	if (cancelRequested.load()) {
		finalResult.error = "chunked transcription was cancelled";
		if (finalResult.success) {
			finalResult.text += "\n\n(cancelled)";
		}
	}
	if (!finalResult.success && finalResult.error.empty()) {
		finalResult.error = "chunked transcription produced no transcript segments";
	}
	return finalResult;
}

void ofApp::setStatus(const std::string & nextStatus, const std::string & nextDetail) {
	std::lock_guard<std::mutex> lock(stateMutex);
	status = nextStatus;
	detail = nextDetail;
	if (nextStatus != "cancelling") {
		output.clear();
		running.store(false);
	}
}

std::string ofApp::findFirstFile(const std::vector<std::string> & directories, const std::vector<std::string> & extensions) {
	std::vector<std::filesystem::path> roots;
	roots.push_back(std::filesystem::current_path());
	roots.push_back(std::filesystem::path(ofToDataPath("", true)));

	for (const auto & root : roots) {
		for (const auto & directory : directories) {
			const auto searchPath = (root / directory).lexically_normal();
			std::error_code error;
			if (!std::filesystem::is_directory(searchPath, error)) {
				continue;
			}
			for (const auto & entry : std::filesystem::directory_iterator(searchPath, error)) {
				if (error) {
					break;
				}
				const auto extension = entry.path().extension().string();
				if (entry.is_regular_file(error) &&
					std::find(extensions.begin(), extensions.end(), extension) != extensions.end()) {
					return normalizePath(entry.path());
				}
			}
		}
	}
	return {};
}

void ofApp::copyToBuffer(std::array<char, 1024> & buffer, const std::string & value) {
	std::fill(buffer.begin(), buffer.end(), '\0');
	const auto count = std::min(buffer.size() - 1, value.size());
	std::copy_n(value.begin(), count, buffer.begin());
}

void ofApp::copyToBuffer(std::array<char, 64> & buffer, const std::string & value) {
	std::fill(buffer.begin(), buffer.end(), '\0');
	const auto count = std::min(buffer.size() - 1, value.size());
	std::copy_n(value.begin(), count, buffer.begin());
}
