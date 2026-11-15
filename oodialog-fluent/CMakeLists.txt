# Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
cmake_minimum_required(VERSION 3.16)
project(OodFluentCore LANGUAGES CXX)
find_package(Threads REQUIRED)

add_library(oodfluent_core STATIC src/OodFluentCore.cpp src/OodFluentABI.cpp)
target_include_directories(oodfluent_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_features(oodfluent_core PUBLIC cxx_std_17)

add_executable(oodfluent_model_test tests/model_test.cpp)
target_link_libraries(oodfluent_model_test PRIVATE oodfluent_core Threads::Threads)
enable_testing()
add_test(NAME oodfluent_control_contract
  COMMAND oodfluent_model_test ${CMAKE_CURRENT_SOURCE_DIR}/catalogue/controls.tsv)
