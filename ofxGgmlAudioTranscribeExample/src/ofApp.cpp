#include "ofApp.h"

#include "imgui.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <vector>

namespace {
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
}

void ofApp::setup() {
	ofSetWindowTitle("ofxGgmlAudio transcribe example");
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
	ofLogNotice("ofxGgmlAudioTranscribeExample") << detail;
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
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		statusSnapshot = status;
		detailSnapshot = detail;
		outputSnapshot = output;
	}

	gui.begin();

	ImGui::SetNextWindowPos(ImVec2(16.0f, 16.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(fitWindowSize(920.0f, 620.0f), ImGuiCond_Once);
	ImGui::Begin("ofxGgmlAudio Transcribe Example");

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
	if (!canEdit) {
		ImGui::EndDisabled();
	}

	if (isRunning) {
		ImGui::BeginDisabled();
	}
	if (ImGui::Button("Run")) {
		startTranscription();
	}
	if (isRunning) {
		ImGui::EndDisabled();
	}
	ImGui::SameLine();
	ImGui::TextUnformatted(isRunning ? "running" : statusSnapshot.c_str());

	ImGui::SeparatorText("Status");
	ImGui::TextWrapped("%s", detailSnapshot.c_str());
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
		detail = "Transcribing " + request.audioPath;
		output.clear();
		result = ofxGgmlAudioResult {};
	}
	running.store(true);
	ofLogNotice("ofxGgmlAudioTranscribeExample")
		<< "model: " << settings.modelPath;
	ofLogNotice("ofxGgmlAudioTranscribeExample")
		<< "audio: " << request.audioPath;

	worker = std::thread(&ofApp::runWorker, this);
}

void ofApp::runWorker() {
	auto setupResult = backend.setup(settings);
	if (!setupResult) {
		ofLogWarning("ofxGgmlAudioTranscribeExample") << setupResult.error;
		setStatus("setup failed", setupResult.error);
		return;
	}

	auto transcribeResult = backend.transcribe(request);
	if (!transcribeResult) {
		ofLogWarning("ofxGgmlAudioTranscribeExample") << transcribeResult.error;
		setStatus("transcription failed", transcribeResult.error);
		return;
	}

	ofLogNotice("ofxGgmlAudioTranscribeExample") << transcribeResult.text;
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		result = transcribeResult;
		output = transcribeResult.text;
		status = "complete";
		detail = "Transcription complete";
	}
	running.store(false);
}

void ofApp::setStatus(const std::string & nextStatus, const std::string & nextDetail) {
	std::lock_guard<std::mutex> lock(stateMutex);
	status = nextStatus;
	detail = nextDetail;
	output.clear();
	running.store(false);
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
