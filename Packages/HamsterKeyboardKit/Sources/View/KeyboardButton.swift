//
//  KeyboardButton.swift
//
//
//  Created by morse on 2023/8/6.
//

import UIKit

/// 键盘键盘
public class KeyboardButton: UIControl {
  typealias ButtonWidth = CGFloat
  
  // MARK: - Properties
  
  /// 布局中所处行，从 0 开始
  public let row: Int
  
  /// 布局中所处列，从 0 开始
  public let column: Int
  
  /// 是否用来填充空白
  /// 如: 标准键盘第二行 A 键的右边, L 键的左边等
  public let isSpacer: Bool
  
  /// 对应布局的 item，存储按键的 action 信息
  /// 注意：item中尺寸信息在自动布局中不在使用了，这些信息在 SwiftUI 布局中使用
  public let item: KeyboardLayoutItem
  
  /// 按键对应的操作
  private let action: KeyboardAction
  
  /// 按键对应操作的处理类
  private let actionHandler: KeyboardActionHandler
  
  /// 键盘上下文
  private let keyboardContext: KeyboardContext
  
  /// 键盘外观
  private let appearance: KeyboardAppearance
  
  /// 呼出的上下文
  private let calloutContext: KeyboardCalloutContext?
  
  @Published
  private var isPressed = false
  
  /// 需要动态调整大小的约束
  public var topConstraints = [NSLayoutConstraint]()
  public var bottomConstraints = [NSLayoutConstraint]()
  public var leadingConstraints = [NSLayoutConstraint]()
  public var trailingConstraints = [NSLayoutConstraint]()
  
  /// 设备方向
  private var interfaceOrientation: InterfaceOrientation
  
  /// 按键内容视图
  private var buttonContentView: KeyboardButtonContentView!
  
  /// 按键阴影路径缓存
  private var shadowPathCache = [ButtonWidth: UIBezierPath]()
  
  /// 按键 underPath 缓存
  private var underPathCache = [ButtonWidth: UIBezierPath]()
  
  /// 按钮背景图
  private lazy var backgroundView: ShapeView = {
    let view = ShapeView()
    view.isOpaque = false
    view.layer.shouldRasterize = true
    view.layer.rasterizationScale = UIScreen.main.scale
    return view
  }()

  // MARK: - 计算属性
  
  /// 按钮样式
  /// 注意：action 与 是否按下的状态 isPressed 决定按钮样式
  private var buttonStyle: KeyboardButtonStyle {
    appearance.buttonStyle(for: item.action, isPressed: isSelected)
  }
  
  /// 布局配置
  private var layoutConfig: KeyboardLayoutConfiguration {
    .standard(for: keyboardContext)
  }
  
  // MARK: - Initializations
  
  init(
    row: Int,
    column: Int,
    item: KeyboardLayoutItem,
    actionHandler: KeyboardActionHandler,
    keyboardContext: KeyboardContext,
    calloutContext: KeyboardCalloutContext?,
    appearance: KeyboardAppearance)
  {
    self.row = row
    self.column = column
    self.item = item
    self.action = item.action
    self.isSpacer = item.action.isSpacer
    self.actionHandler = actionHandler
    self.keyboardContext = keyboardContext
    self.calloutContext = calloutContext
    self.appearance = appearance
    self.interfaceOrientation = keyboardContext.interfaceOrientation
    
    super.init(frame: .zero)
    
    self.buttonContentView = KeyboardButtonContentView(
      action: action,
      style: buttonStyle,
      appearance: appearance,
      keyboardContext: keyboardContext)
    
    setupSubview()
  }
  
  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Layout Functions
  
  override public var isSelected: Bool {
    didSet {
      print("button isSelected")
      buttonContentView.style = buttonStyle
      updateButtonStyle(layoutConfig)
    }
  }

  func setupSubview() {
    /// spacer 类型不可见
    alpha = isSpacer ? 0 : 1
    
    let layoutConfig = layoutConfig
    setupContentView(layoutConfig)
    setupBackgroundView(layoutConfig)
    
    NSLayoutConstraint.activate(topConstraints + bottomConstraints + leadingConstraints + trailingConstraints)
  }

  /// 设置按钮内容视图
  func setupContentView(_ layoutConfig: KeyboardLayoutConfiguration) {
    // 不变的样式
    buttonContentView.layer.cornerRadius = cornerRadius
    
    addSubview(buttonContentView)
    buttonContentView.translatesAutoresizingMaskIntoConstraints = false
    let insets = layoutConfig.buttonInsets
    topConstraints.append(buttonContentView.topAnchor.constraint(equalTo: topAnchor, constant: insets.top))
    bottomConstraints.append(buttonContentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom))
    leadingConstraints.append(buttonContentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left))
    trailingConstraints.append(buttonContentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right))
  }
  
  func setupBackgroundView(_ layoutConfig: KeyboardLayoutConfiguration) {
    // 不变的样式
    backgroundView.shapeLayer.lineWidth = 1
    backgroundView.shapeLayer.fillColor = UIColor.clear.cgColor
    backgroundView.shapeLayer.shadowOpacity = Float(0.2)
    backgroundView.shapeLayer.masksToBounds = false
    
    insertSubview(backgroundView, belowSubview: buttonContentView)
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    let insets = layoutConfig.buttonInsets
    topConstraints.append(backgroundView.topAnchor.constraint(equalTo: topAnchor, constant: insets.top))
    bottomConstraints.append(backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom))
    leadingConstraints.append(backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left))
    trailingConstraints.append(backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right))
  }
  
  func updateConstraints(_ layoutConfig: KeyboardLayoutConfiguration) {
    guard interfaceOrientation != keyboardContext.interfaceOrientation else { return }

    interfaceOrientation = keyboardContext.interfaceOrientation

    let insets = layoutConfig.buttonInsets

    // Logger.statistics.debug("KeyboardButtonRowItem layoutSubviews() rowHeight: \(layoutConfig.rowHeight), buttonInsets [left: \(insets.left), top: \(insets.top), right: \(insets.right), bottom: \(insets.bottom)]")

    topConstraints.forEach { $0.constant = insets.top }
    bottomConstraints.forEach { $0.constant = -insets.bottom }
    leadingConstraints.forEach { $0.constant = insets.left }
    trailingConstraints.forEach { $0.constant = -insets.right }
  }
  
  func updateButtonStyle(_ layoutConfig: KeyboardLayoutConfiguration) {
    let style = buttonStyle
    let isPressed = isSelected
    
    // 按钮样式
    if isPressed {
      buttonContentView.backgroundColor = style.pressedOverlayColor ?? .clear
    } else {
      buttonContentView.backgroundColor = style.backgroundColor ?? .clear
    }
    
    // 按键底部深色样式
    backgroundView.layer.borderColor = style.border?.color.cgColor ?? UIColor.clear.cgColor
    
    backgroundView.shapeLayer.path = underPath.cgPath
    backgroundView.shapeLayer.strokeColor = (style.shadow?.color ?? UIColor.clear).cgColor
    
    // 按键阴影样式
    backgroundView.layer.shadowPath = shadowPath.cgPath
    backgroundView.layer.shadowColor = (style.shadow?.color ?? UIColor.clear).cgColor
  }
  
  override public func layoutSubviews() {
    super.layoutSubviews()
    
    let layoutConfig = layoutConfig
    updateConstraints(layoutConfig)
    updateButtonStyle(layoutConfig)
  }
}

// MARK: - background view style

extension KeyboardButton {
  var cornerRadius: CGFloat {
    buttonStyle.cornerRadius ?? .zero
  }
  
  /// 按钮阴影路径
  var shadowPath: UIBezierPath {
//    let buttonWidth: ButtonWidth = bounds.width
    // TODO: 缓存存在问题, UI显示的路径不正确
//    if let path = shadowPathCache[buttonWidth] {
//      return path
//    }
    let shadowSize = buttonStyle.shadow?.size ?? 1
    let rect = CGRect(
      x: 0,
      y: backgroundView.bounds.height,
      width: backgroundView.bounds.width,
      height: shadowSize)
    let path = UIBezierPath(
      roundedRect: rect,
      cornerRadius: shadowSize)
//    shadowPathCache[buttonWidth] = path
    return path
  }

  /// 按钮底部深色样式路径
  var underPath: UIBezierPath {
//    let buttonWidth: ButtonWidth = bounds.width
    // TODO: 缓存存在问题, UI显示的路径不正确
//    if let path = underPathCache[buttonWidth] {
//      return path
//    }
    let cornerRadius = cornerRadius
    let delta: CGFloat = 0.5 // 线宽的一半，backgroundView.shapeLayer.lineWidth = 1
    let maxX = backgroundView.frame.width - delta
    let maxY = backgroundView.frame.height + delta
    
    // 按钮底部边框
    let underPath: UIBezierPath = {
      // 按钮底部右下圆角
      let path = UIBezierPath(
        arcCenter: CGPoint(x: maxX - cornerRadius, y: maxY - cornerRadius), // 圆心
        radius: cornerRadius,
        startAngle: 0,
        endAngle: CGFloat.pi / 2,
        clockwise: true)

      let point = CGPoint(x: cornerRadius + delta, y: maxY)
      path.addLine(to: point)

      // 按钮底部左下圆角
      path.addArc(
        withCenter: CGPoint(x: cornerRadius + delta, y: maxY - cornerRadius), // 圆心
        radius: cornerRadius,
        startAngle: CGFloat.pi / 2,
        endAngle: CGFloat.pi,
        clockwise: true)
      return path
    }()
    
//    underPathCache[buttonWidth] = underPath
    
    return underPath
  }
}

/// layer 层为 CAShapeLayer 的 UIView
public class ShapeView: UIView {
  public var shapeLayer: CAShapeLayer!

  override public class var layerClass: AnyClass {
    return CAShapeLayer.self
  }

  override public init(frame: CGRect = .zero) {
    super.init(frame: frame)

    self.shapeLayer = layer as? CAShapeLayer
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

#if canImport(SwiftUI) && DEBUG
import SwiftUI

struct KeyboardButtonView_Previews: PreviewProvider {
  static func button(for action: KeyboardAction) -> some View {
    return UIViewPreview {
      let button = KeyboardButton(
        row: 0,
        column: 0,
        item: .init(action: action, size: .init(width: .input, height: 54), insets: .zero),
        actionHandler: .preview,
        keyboardContext: .preview,
        calloutContext: .disabled,
        appearance: .preview)
      
      button.frame = .init(x: 0, y: 0, width: 80, height: 80)
      return button
    }
  }

  static var previews: some View {
    VStack {
      button(for: .backspace)
      button(for: .space)
      button(for: .nextKeyboard)
      button(for: .character("a"))
      button(for: .character("A"))
    }
    .padding()
    .background(Color.gray)
    .cornerRadius(10)
    .environment(\.sizeCategory, .extraExtraLarge)
  }
}

#endif
