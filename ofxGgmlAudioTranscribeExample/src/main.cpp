#include "ofMain.h"
#include "ofApp.h"

#include <cstdlib>
#include <string>

namespace {
	bool autoRunEnabled() {
		const char * value = std::getenv("OFXGGML_AUDIO_AUTORUN");
		if (!value) {
			return false;
		}
		const std::string flag(value);
		return flag == "1" || flag == "true" || flag == "on" || flag == "yes";
	}
}

int main() {
#ifdef TARGET_WIN32
	if (autoRunEnabled()) {
		ofLogToConsole();
	} else {
		ofLogToDebugView();
	}
#endif
	ofSetupOpenGL(960, 540, OF_WINDOW);
	auto app = std::make_shared<ofApp>();
	ofRunApp(app);
	return app->getExitCode();
}
