meta:
	ADDON_NAME = ofxGgmlAudio
	ADDON_DESCRIPTION = Companion addon for local audio inference, speech recognition, and voice workflows on top of ofxGgmlCore
	ADDON_AUTHOR = Jonathan Frank
	ADDON_TAGS = "ggml,ai,audio,speech,whisper,transcription,denoising,voice"
	ADDON_URL = https://github.com/Jonathhhan/ofxGgmlAudio

common:
	ADDON_DEPENDENCIES += ofxGgmlCore
	ADDON_INCLUDES += src
	ADDON_SOURCES_EXCLUDE += build/%
	ADDON_SOURCES_EXCLUDE += libs/*/build/%
	ADDON_SOURCES_EXCLUDE += libs/*/build*/%
	ADDON_INCLUDES_EXCLUDE += build/%
	ADDON_INCLUDES_EXCLUDE += libs/*/build/%
	ADDON_INCLUDES_EXCLUDE += libs/*/build*/%
