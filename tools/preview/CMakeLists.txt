juce_add_gui_app(ShoreveilPreview
    PRODUCT_NAME "Shoreveil Preview"
    COMPANY_NAME "WTdusk"
    BUNDLE_ID "io.github.wtdusk.rivage.preview")

target_sources(ShoreveilPreview PRIVATE Main.cpp)

target_include_directories(ShoreveilPreview PRIVATE ${CMAKE_SOURCE_DIR}/Source)

target_compile_definitions(ShoreveilPreview PRIVATE
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
    JUCE_APPLICATION_NAME_STRING="$<TARGET_PROPERTY:ShoreveilPreview,JUCE_PRODUCT_NAME>"
    JUCE_APPLICATION_VERSION_STRING="$<TARGET_PROPERTY:ShoreveilPreview,JUCE_VERSION>")

target_link_libraries(ShoreveilPreview PRIVATE
    ShoreveilReverb
    juce::juce_audio_utils
    juce::juce_dsp
    juce::juce_gui_basics
    juce::juce_recommended_config_flags
    juce::juce_recommended_warning_flags)
