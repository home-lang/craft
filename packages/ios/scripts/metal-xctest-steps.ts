/** Compilation must finish before the full XCTest execution budget starts. */
export function metalXCTestSteps(simulator: string, derivedData: string, results: string): { name: string, args: string[], timeoutMs: number }[] {
  const common = ['xcodebuild', '-project', 'MetalSurfaceFixture.xcodeproj', '-scheme', 'MetalSurfaceFixture', '-destination', `platform=iOS Simulator,id=${simulator}`, '-derivedDataPath', derivedData, '-parallel-testing-enabled', 'NO', 'CODE_SIGN_IDENTITY=-', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGNING_ALLOWED=NO', 'ONLY_ACTIVE_ARCH=YES']
  return [
    { name: 'build-native-uikit-tests', args: [...common, 'build-for-testing'], timeoutMs: 300_000 },
    { name: 'native-uikit-tests', args: [...common, '-resultBundlePath', results, 'test-without-building'], timeoutMs: 300_000 },
  ]
}
