#include "ofMain.h"
#include "ofApp.h"

int main() {
#ifdef TARGET_WIN32
	ofLogToDebugView();
#endif
	ofSetupOpenGL(960, 540, OF_WINDOW);
	ofRunApp(new ofApp());
}
