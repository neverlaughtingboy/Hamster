import Combine
import Foundation
import KeyboardKit
import LibrimeKit
import UIKit

/// 键盘ViewController
open class HamsterKeyboardViewController: KeyboardInputViewController {
  public var rimeEngine = RimeEngine.shared
  public var appSettings = HamsterAppSettings()
  private let log = Logger.shared.log

  var cancel = Set<AnyCancellable>()

  override public func viewDidLoad() {
    self.log.info("viewDidLoad() begin")

    do {
      try RimeEngine.syncAppGroupSharedSupportDirectory()
      try RimeEngine.initUserDataDirectory()
      try RimeEngine.syncAppGroupUserDataDirectory()
    } catch {
      // TODO: RIME 异常启动处理
      self.log.error("create rime directory error: \(error), \(error.localizedDescription)")
//      fatalError(error.localizedDescription)
    }

    self.rimeEngine.setupRime(
      sharedSupportDir: RimeEngine.sharedSupportDirectory.path,
      userDataDir: RimeEngine.userDataDirectory.path
    )
    self.rimeEngine.startRime()

    self.appSettings.$switchTraditionalChinese
      .receive(on: RunLoop.main)
      .sink {
        self.log.info("combine $switchTraditionalChinese \($0)")
        _ = self.rimeEngine.simplifiedChineseMode($0)
      }
      .store(in: &self.cancel)

    self.appSettings.$showKeyPressBubble
      .receive(on: RunLoop.main)
      .sink {
        self.log.info("combine $showKeyPressBubble \($0)")
        self.calloutContext.input.isEnabled = $0
      }
      .store(in: &self.cancel)

    self.appSettings.$rimeNeedOverrideUserDataDirectory
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.log.info("combine $rimeNeedOverrideUserDataDirectory \($0)")
        if $0 {
          do {
            try RimeEngine.syncAppGroupSharedSupportDirectory(override: true)
            try RimeEngine.syncAppGroupUserDataDirectory(override: true)
          } catch {
            self?.log.error("rime syncAppGroupUserDataDirectory error \(error), \(error.localizedDescription)")
          }
          self?.rimeEngine.deploy(fullCheck: false)
        }
      }
      .store(in: &self.cancel)

    self.appSettings.$rimeInputSchema
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        if !$0.isEmpty {
          if !(self?.rimeEngine.setSchema($0) ?? false) {
            self?.log.error("rime engine set schema \($0) error")
          }
        }
      }
      .store(in: &self.cancel)

    // 注意初始化的顺序
    self.keyboardAppearance = HamsterKeyboardAppearance(
      keyboardContext: self.keyboardContext,
      appSettings: self.appSettings,
      rimeEngine: self.rimeEngine
    )

    self.keyboardLayoutProvider = HamsterStandardKeyboardLayoutProvider(
      keyboardContext: self.keyboardContext,
      inputSetProvider: self.inputSetProvider,
      appSettings: self.appSettings
    )

    self.keyboardBehavior = HamsterKeyboardBehavior(keyboardContext: self.keyboardContext)
    self.calloutActionProvider = DisabledCalloutActionProvider() // 禁用长按按钮

    self.keyboardFeedbackSettings = KeyboardFeedbackSettings(
      audioConfiguration: AudioFeedbackConfiguration(),
      hapticConfiguration: HapticFeedbackConfiguration(
        tap: .mediumImpact,
        doubleTap: .mediumImpact,
        longPress: .mediumImpact,
        longPressOnSpace: .mediumImpact
      )
    )
    self.keyboardFeedbackHandler = HamsterKeyboardFeedbackHandler(
      settings: self.keyboardFeedbackSettings,
      appSettings: self.appSettings
    )

    self.keyboardActionHandler = HamsterKeyboardActionHandler(inputViewController: self)
    self.calloutContext = KeyboardCalloutContext(
      action: HamsterActionCalloutContext(
        actionHandler: keyboardActionHandler,
        actionProvider: calloutActionProvider
      ),
      input: InputCalloutContext(
        isEnabled: UIDevice.current.userInterfaceIdiom == .phone)
    )

    // TODO: 动态设置 local
    self.keyboardContext.locale = Locale(identifier: "zh-Hans")

    super.viewDidLoad()
  }

  override public func viewDidDisappear(_ animated: Bool) {
    self.log.debug("viewDidDisappear() begin")
  }

  override public func viewWillSetupKeyboard() {
    self.log.debug("viewWillSetupKeyboard() begin")

    let alphabetKeyboard = AlphabetKeyboard(keyboardInputViewController: self)
      .environmentObject(self.rimeEngine)
      .environmentObject(self.appSettings)
    setup(with: alphabetKeyboard)
  }
}

public extension HamsterKeyboardViewController {
  //    func insertAutocompleteSuggestion(_ suggestion: AutocompleteSuggestion) {
  //        textDocumentProxy.insertAutocompleteSuggestion(suggestion)
  //        keyboardActionHandler.handle(.release, on: .character(""))
  //    }

  func setHamsterKeyboardType(_ type: KeyboardType) {
    // TODO: 切换九宫格
    //        if case .numeric = type {
    //            keyboardContext.keyboardType = .custom(named: KeyboardConstant.keyboardType.NumberGrid)
    //            return
    //        }
    keyboardContext.keyboardType = type
  }
}
