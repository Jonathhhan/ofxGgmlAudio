#include "ofMain.h"
#include "ofApp.h"

#include <cstdlib>
#include <fstream>
#include <string>

namespace {
	bool startupProbeEnabled() {
		const auto value = std::getenv("OFXGGML_AUDIO_STARTUP_PROBE");
		return value != nullptr && std::string(value) != "0" && std::string(value) != "false";
	}

	std::string startupProbePath() {
		const auto explicitPath = std::getenv("OFXGGML_AUDIO_STARTUP_PROBE_PATH");
		if (explicitPath != nullptr && std::string(explicitPath).size() > 0) {
			return explicitPath;
		}

		const auto temp = std::getenv("TEMP");
		if (temp != nullptr && std::string(temp).size() > 0) {
			return std::string(temp) + "\\ofxGgmlAudioLiveMic-startup.txt";
		}
		return "ofxGgmlAudioLiveMic-startup.txt";
	}

	void writeStartupProbe(const std::string & message) {
		if (!startupProbeEnabled()) {
			return;
		}
		std::ofstream out(startupProbePath(), std::ios::app);
		out << message << std::endl;
	}
}

int main() {
	writeStartupProbe("main: before ofSetupOpenGL");
	ofSetupOpenGL(960, 540, OF_WINDOW);
	writeStartupProbe("main: after ofSetupOpenGL");
	writeStartupProbe("main: before ofRunApp");
	ofRunApp(new ofApp());
	writeStartupProbe("main: after ofRunApp");
}
