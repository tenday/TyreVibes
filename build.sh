#!/bin/bash

# TyreVibes Android Build Launcher
# Usage: ./build.sh [command]

set -e

cd "$(dirname "$0")/android"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}  TyreVibes Android Build Tool  ${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Parse command argument
COMMAND=${1:-help}

case "$COMMAND" in
    debug)
        echo -e "${GREEN}Building Debug APK...${NC}"
        ./gradlew assembleDebug
        echo -e "${GREEN}✓ Debug APK built successfully!${NC}"
        echo -e "${YELLOW}APK location: android/app/build/outputs/apk/debug/app-debug.apk${NC}"
        ;;

    release)
        echo -e "${GREEN}Building Release APK...${NC}"
        ./gradlew assembleRelease
        echo -e "${GREEN}✓ Release APK built successfully!${NC}"
        echo -e "${YELLOW}APK location: android/app/build/outputs/apk/release/app-release.apk${NC}"
        ;;

    build)
        echo -e "${GREEN}Running full build (Debug + Release)...${NC}"
        ./gradlew build
        echo -e "${GREEN}✓ Build completed successfully!${NC}"
        ;;

    clean)
        echo -e "${YELLOW}Cleaning build artifacts...${NC}"
        ./gradlew clean
        echo -e "${GREEN}✓ Clean completed!${NC}"
        ;;

    rebuild)
        echo -e "${YELLOW}Cleaning...${NC}"
        ./gradlew clean
        echo -e "${GREEN}Building Debug APK...${NC}"
        ./gradlew assembleDebug
        echo -e "${GREEN}✓ Rebuild completed successfully!${NC}"
        ;;

    install)
        echo -e "${GREEN}Installing Debug APK on connected device...${NC}"
        ./gradlew installDebug
        echo -e "${GREEN}✓ App installed successfully!${NC}"
        ;;

    run)
        echo -e "${GREEN}Building and installing Debug APK...${NC}"
        ./gradlew installDebug
        echo -e "${GREEN}✓ App installed!${NC}"
        echo -e "${YELLOW}Launch the app manually from your device/emulator${NC}"
        ;;

    test)
        echo -e "${GREEN}Running tests...${NC}"
        ./gradlew test
        echo -e "${GREEN}✓ Tests completed!${NC}"
        ;;

    compile)
        echo -e "${GREEN}Compiling Kotlin code (checking for errors)...${NC}"
        ./gradlew compileDebugKotlin
        echo -e "${GREEN}✓ Compilation successful!${NC}"
        ;;

    errors)
        echo -e "${YELLOW}Checking for compilation errors...${NC}"
        ./gradlew compileDebugKotlin 2>&1 | grep "^e:" | head -50
        ;;

    tasks)
        echo -e "${GREEN}Available Gradle tasks:${NC}"
        ./gradlew tasks
        ;;

    help)
        echo -e "${GREEN}Available commands:${NC}"
        echo ""
        echo -e "  ${BLUE}debug${NC}      - Build Debug APK (fastest)"
        echo -e "  ${BLUE}release${NC}    - Build Release APK"
        echo -e "  ${BLUE}build${NC}      - Full build (Debug + Release)"
        echo -e "  ${BLUE}clean${NC}      - Clean build artifacts"
        echo -e "  ${BLUE}rebuild${NC}    - Clean + Build Debug"
        echo -e "  ${BLUE}install${NC}    - Install Debug APK on device/emulator"
        echo -e "  ${BLUE}run${NC}        - Build + Install Debug APK"
        echo -e "  ${BLUE}test${NC}       - Run unit tests"
        echo -e "  ${BLUE}compile${NC}    - Compile Kotlin code only (quick error check)"
        echo -e "  ${BLUE}errors${NC}     - Show compilation errors"
        echo -e "  ${BLUE}tasks${NC}      - Show all available Gradle tasks"
        echo -e "  ${BLUE}help${NC}       - Show this help message"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  ./build.sh debug"
        echo -e "  ./build.sh install"
        echo -e "  ./build.sh rebuild"
        echo ""
        ;;

    *)
        echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
        echo -e "${YELLOW}Run './build.sh help' for available commands${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}=================================${NC}"
