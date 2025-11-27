/**
 * Craft Detox Configuration
 * E2E testing for iOS and Android mobile apps
 */

export interface DetoxConfig {
  testRunner: {
    args: {
      $0: string
      config: string
    }
    jest: {
      setupTimeout: number
    }
  }
  apps: {
    [key: string]: {
      type: 'ios.app' | 'android.apk'
      binaryPath: string
      build?: string
    }
  }
  devices: {
    [key: string]:
      | {
          type: 'ios.simulator'
          device: {
            type: string
          }
        }
      | {
          type: 'android.emulator'
          device: {
            avdName: string
          }
        }
      | {
          type: 'android.attached'
          device: {
            adbName: string
          }
        }
  }
  configurations: {
    [key: string]: {
      device: string
      app: string
    }
  }
}

export const detoxConfig: DetoxConfig = {
  testRunner: {
    args: {
      $0: 'jest',
      config: 'e2e/jest.config.js',
    },
    jest: {
      setupTimeout: 120000,
    },
  },
  apps: {
    'ios.debug': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Debug-iphonesimulator/CraftApp.app',
      build: 'xcodebuild -workspace ios/CraftApp.xcworkspace -scheme CraftApp -configuration Debug -sdk iphonesimulator -derivedDataPath ios/build',
    },
    'ios.release': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Release-iphonesimulator/CraftApp.app',
      build: 'xcodebuild -workspace ios/CraftApp.xcworkspace -scheme CraftApp -configuration Release -sdk iphonesimulator -derivedDataPath ios/build',
    },
    'android.debug': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/debug/app-debug.apk',
      build: 'cd android && ./gradlew assembleDebug assembleAndroidTest -DtestBuildType=debug',
    },
    'android.release': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/release/app-release.apk',
      build: 'cd android && ./gradlew assembleRelease assembleAndroidTest -DtestBuildType=release',
    },
  },
  devices: {
    simulator: {
      type: 'ios.simulator',
      device: {
        type: 'iPhone 15',
      },
    },
    'simulator.ipad': {
      type: 'ios.simulator',
      device: {
        type: 'iPad Pro (12.9-inch) (6th generation)',
      },
    },
    emulator: {
      type: 'android.emulator',
      device: {
        avdName: 'Pixel_7_API_34',
      },
    },
    'attached.device': {
      type: 'android.attached',
      device: {
        adbName: '.*',
      },
    },
  },
  configurations: {
    'ios.sim.debug': {
      device: 'simulator',
      app: 'ios.debug',
    },
    'ios.sim.release': {
      device: 'simulator',
      app: 'ios.release',
    },
    'ios.ipad.debug': {
      device: 'simulator.ipad',
      app: 'ios.debug',
    },
    'android.emu.debug': {
      device: 'emulator',
      app: 'android.debug',
    },
    'android.emu.release': {
      device: 'emulator',
      app: 'android.release',
    },
    'android.device.release': {
      device: 'attached.device',
      app: 'android.release',
    },
  },
}

export default detoxConfig
