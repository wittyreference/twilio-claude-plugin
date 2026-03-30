---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Complete CallKit and PushKit integration guide for Twilio Voice iOS SDK. -->
<!-- ABOUTME: Covers VoIP push certificate setup, PushKit registration, CallKit provider, and incoming/outgoing call flows. -->

# CallKit & PushKit Integration

Deep dive into the iOS-specific call handling infrastructure required for Twilio Voice SDK. This is the most complex part of iOS Voice integration — getting it wrong causes silent failures that are hard to debug.

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Apple Developer Account | Paid account required for VoIP push certificates |
| Xcode Capability | Enable "Voice over IP" in Background Modes |
| Info.plist | `UIBackgroundModes` array includes `voip` |
| Physical device | VoIP push does not work on simulator |

## VoIP Push Certificate Setup

### Step 1: Generate Certificate

1. Go to Apple Developer Portal → Certificates, Identifiers & Profiles
2. Create a new certificate → VoIP Services Certificate
3. Select your App ID
4. Generate and download the `.cer` file
5. Double-click to install in Keychain Access

### Step 2: Export as .p12

1. Open Keychain Access → My Certificates
2. Find your VoIP Services certificate
3. Right-click → Export → Save as `.p12`

### Step 3: Extract PEM Files

```bash
# Extract certificate
openssl pkcs12 -in voip-cert.p12 -nokeys -out cert.pem -nodes
openssl x509 -in cert.pem -out cert.pem

# Extract private key
openssl pkcs12 -in voip-cert.p12 -nocerts -out key.pem -nodes
openssl rsa -in key.pem -out key.pem
```

If you hit `unsupported encryption algorithm (RC2-40-CBC)`, add `-legacy` to the `openssl pkcs12` commands. This happens with modern OpenSSL versions processing older certificate formats.

### Step 4: Create Twilio Push Credential

```bash
# Sandbox (development)
twilio api:chat:v2:credentials:create \
  --type=apn \
  --sandbox \
  --friendly-name="voip-push-sandbox" \
  --certificate="$(cat cert.pem)" \
  --private-key="$(cat key.pem)"

# Production (App Store)
twilio api:chat:v2:credentials:create \
  --type=apn \
  --friendly-name="voip-push-production" \
  --certificate="$(cat cert.pem)" \
  --private-key="$(cat key.pem)"
```

This returns a `CRxxxxx` SID. Include it in your AccessToken's Voice grant as `pushCredentialSid`.

**Separate sandbox from production**: Use different Twilio accounts or subaccounts. Mixing sandbox and production push credentials is the #1 cause of "pushes work in dev but not in TestFlight/App Store."

## PushKit Registration (Swift)

```swift
import PushKit

class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate {
    var voipRegistry: PKPushRegistry!
    var deviceToken: Data?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        return true
    }

    // Called when device token is assigned or refreshed
    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {
        guard type == .voIP else { return }
        deviceToken = pushCredentials.token

        // Register with Twilio
        TwilioVoiceSDK.register(accessToken: accessToken,
                                deviceToken: pushCredentials.token) { error in
            if let error = error {
                print("Registration failed: \(error.localizedDescription)")
            }
        }
    }

    // iOS 13+ CRITICAL: Must report to CallKit immediately
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload,
                                           delegate: self,
                                           delegateQueue: nil)

        // If handleNotification does not produce a callInvite quickly,
        // you MUST still call reportNewIncomingCall to avoid termination.
        // Implement a timeout fallback.
        completion()
    }
}
```

### iOS 13+ Mandatory Behavior

Starting with iOS 13, Apple enforces that every VoIP push MUST result in a `reportNewIncomingCall` to CallKit. If your app receives a VoIP push and does not call `reportNewIncomingCall` within a few seconds:

1. **First offense**: System logs a warning
2. **Repeated offenses**: System stops delivering VoIP pushes to your app entirely
3. **Recovery**: Uninstall and reinstall the app

This means you need defensive coding: even if the push payload is malformed or the Twilio SDK fails to parse it, report a "call" to CallKit and immediately end it if needed.

## CallKit Provider Setup

```swift
class CallManager: NSObject, CXProviderDelegate {
    let provider: CXProvider
    let callController = CXCallController()
    var activeCallInvite: TVOCallInvite?
    var activeCall: TVOCall?
    var activeCallUUID: UUID?

    override init() {
        let config = CXProviderConfiguration()
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = false
        config.supportedHandleTypes = [.phoneNumber, .generic]
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        TwilioVoiceSDK.audioDevice.isEnabled = false
        activeCall?.disconnect()
        activeCall = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        TwilioVoiceSDK.audioDevice.isEnabled = false  // disabled until didActivate

        guard let invite = activeCallInvite else {
            action.fail()
            return
        }

        let acceptOptions = AcceptOptions(callInvite: invite) { builder in
            builder.uuid = action.callUUID
        }
        activeCall = invite.accept(options: acceptOptions, delegate: self)
        activeCallInvite = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        TwilioVoiceSDK.audioDevice.isEnabled = false
        activeCall?.disconnect()
        activeCallInvite?.reject()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        activeCall?.isOnHold = action.isOnHold
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        activeCall?.isMuted = action.isMuted
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        TwilioVoiceSDK.audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        TwilioVoiceSDK.audioDevice.isEnabled = false
    }
}
```

## Incoming Call Flow (Complete)

```
VoIP Push (APNs) → PushKit handler → TwilioVoiceSDK.handleNotification()
    ↓
TVONotificationDelegate.callInviteReceived() → store invite
    ↓
CXProvider.reportNewIncomingCall() → system call UI appears
    ↓
User taps Accept → CXAnswerCallAction fires
    ↓
callInvite.accept(delegate:) → TVOCall created
    ↓
CXProvider.didActivate → audioDevice.isEnabled = true
    ↓
TVOCallDelegate.callDidConnect() → call is live
```

## Outgoing Call Flow (Complete)

```
App UI → CXStartCallAction → CXCallController.request()
    ↓
CXProvider.perform(CXStartCallAction) fires
    ↓
TwilioVoiceSDK.connect(options:delegate:) → TVOCall created
    ↓
CXProvider.didActivate → audioDevice.isEnabled = true
    ↓
TVOCallDelegate.callDidConnect() → call is live
    ↓
provider.reportOutgoingCall(with: uuid, connectedAt: Date())
```

## Unregistration

When the user logs out or you need to stop receiving calls:

```swift
TwilioVoiceSDK.unregister(accessToken: accessToken,
                           deviceToken: deviceToken) { error in
    if let error = error {
        print("Unregister error: \(error.localizedDescription)")
    }
}
```

Cache the device token (e.g., in UserDefaults as `Data`) so you can unregister even if PushKit hasn't refreshed it recently.
