#!/bin/bash

# Script to build NuGet packages from VirtualClient build artifacts

set -e  # Exit on any error

# Global variables
EXIT_CODE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONFIGURATION="Release"
BUILD_VERSION=""
PACKAGE_SUFFIX=""

# Print usage information
usage() {
    cat << EOF

Builds NuGet packages from the artifacts/output of the build process.

Usage: $0 [options]

Options:
  --suffix <alpha|beta>    Add a suffix to package names
  --help                   Display this help message

Examples:
  # Basic usage
  chmod +x *.sh
  ./build.sh
  ./$0

  # With suffix
  ./$0 --suffix beta

  # With environment variables
  export VCBuildVersion="1.16.25"
  export VCBuildConfiguration="Debug"
  ./$0

EOF
    exit 0
}

# Handle errors
error() {
    EXIT_CODE=1
    finish
}

# Clean up and exit
finish() {
    printf '\nPackaging Stage Exit Code: %d\n\n' "$EXIT_CODE"
    exit "$EXIT_CODE"
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h|-?)
                usage
                ;;
            --suffix)
                shift
                case "$1" in
                    alpha|beta) PACKAGE_SUFFIX="$1" ;;
                    *) echo "Error: Invalid suffix '$1'. Use 'alpha' or 'beta'." >&2; error ;;
                esac
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                usage
                ;;
        esac
        shift
    done
}

# Determine build version and configuration
setup_build() {
    # Read version from VERSION file
    BUILD_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "0.0.0")
    
    # Override with environment variable if set
    [ -n "${VCBuildVersion}" ] && BUILD_VERSION="${VCBuildVersion}"
    
    # Override configuration with environment variable if set
    [ -n "${VCBuildConfiguration}" ] && BUILD_CONFIGURATION="${VCBuildConfiguration}"
    
    # Construct package version
    PACKAGE_VERSION="${BUILD_VERSION}${PACKAGE_SUFFIX:+"-$PACKAGE_SUFFIX"}"
}

# Print build information
print_info() {
    cat << EOF

**********************************************************************
Build Version   : $BUILD_VERSION
Repo Root       : $SCRIPT_DIR
Configuration   : $BUILD_CONFIGURATION
Package Version : $PACKAGE_VERSION
**********************************************************************

EOF
}

# Create NuGet package
create_package() {
    local package_name="$1"
    local nuspec_file="$2"
    
    printf '\n[Create NuGet Package] %s.%s\n' "$package_name" "$PACKAGE_VERSION"
    printf '----------------------------------------------------------\n'
    
    dotnet pack "$PACKAGES_PROJECT" \
        --force \
        --no-restore \
        --no-build \
        -c "$BUILD_CONFIGURATION" \
        -p:Version="$PACKAGE_VERSION" \
        -p:NuspecFile="$nuspec_file" || error
}

# Main execution
main() {
    # Check prerequisites
    command -v dotnet >/dev/null 2>&1 || { echo "Error: dotnet CLI not found" >&2; error; }
    [ -f "$SCRIPT_DIR/VERSION" ] || { echo "Warning: VERSION file not found, using default" >&2; }

    parse_args "$@"
    setup_build
    
    PACKAGES_PROJECT_DIR="$SCRIPT_DIR/src/VirtualClient/VirtualClient.Packaging"
    PACKAGES_PROJECT="$PACKAGES_PROJECT_DIR/VirtualClient.Packaging.csproj"
    
    print_info
    
    # Restore packages
    dotnet restore "$PACKAGES_PROJECT" --force || error
    
    # Create packages
    create_package "VirtualClient" "$PACKAGES_PROJECT_DIR/nuspec/VirtualClient.nuspec"
    create_package "VirtualClient.Framework" "$PACKAGES_PROJECT_DIR/nuspec/VirtualClient.Framework.nuspec"
    create_package "VirtualClient.TestFramework" "$PACKAGES_PROJECT_DIR/nuspec/VirtualClient.TestFramework.nuspec"
    
    finish
}

# Trap unexpected exits
trap 'error' ERR

main "$@"
