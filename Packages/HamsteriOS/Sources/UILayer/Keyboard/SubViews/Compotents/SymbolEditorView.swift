//
//  NumberNineGridSymbolListTableView.swift
//  Hamster
//
//  Created by morse on 2023/6/16.
//

import Combine
import HamsterUIKit
import UIKit

/// 符号编辑View
public class SymbolEditorView: NibLessView {
  // MARK: properties

  private var subscriptions = Set<AnyCancellable>()

  private let headerTitle: String
  private let getSymbols: () -> [String]
  private var symbols: [String] {
    didSet {
      symbolsDidSet(symbols)
    }
  }

  private let symbolsDidSet: ([String]) -> Void
  private var symbolTableIsEditingPublished: AnyPublisher<Bool, Never>
  private var reloadDataPublished: AnyPublisher<Bool, Never>

  lazy var headerView: UIView = {
    let titleLabel = UILabel(frame: .zero)
    titleLabel.text = headerTitle
    titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)

    let stackView = UIStackView(arrangedSubviews: [titleLabel])
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.distribution = .equalSpacing
    stackView.spacing = 8

    let containerView = UIView()
    containerView.frame = CGRect(x: 0, y: 0, width: 300, height: 30)
    containerView.addSubview(stackView)
    stackView.fillSuperview()

    return containerView
  }()

  lazy var tableView: UITableView = {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    tableView.register(TextFieldTableViewCell.self, forCellReuseIdentifier: TextFieldTableViewCell.identifier)
    tableView.tableHeaderView = headerView
    tableView.rowHeight = UITableView.automaticDimension
    tableView.allowsSelection = false
    return tableView
  }()

  // MARK: methods

  init(
    frame: CGRect = .zero,
    headerTitle: String,
    getSymbols: @escaping () -> [String],
    symbolsDidSet: @escaping ([String]) -> Void,
    symbolTableIsEditingPublished: AnyPublisher<Bool, Never>,
    reloadDataPublished: AnyPublisher<Bool, Never>
  ) {
    self.headerTitle = headerTitle
    self.getSymbols = getSymbols
    self.symbols = getSymbols()
    self.symbolsDidSet = symbolsDidSet
    self.symbolTableIsEditingPublished = symbolTableIsEditingPublished
    self.reloadDataPublished = reloadDataPublished

    super.init(frame: frame)

    setupTableView()

    self.symbolTableIsEditingPublished
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] in
        tableView.setEditing($0, animated: true)
        if tableView.isEditing {
          tableView.visibleCells.forEach { cell in
            guard let cell = cell as? TextFieldTableViewCell else { return }
            cell.textField.resignFirstResponder()
          }
        }
      }
      .store(in: &subscriptions)

    self.reloadDataPublished
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] _ in
        self.symbols = getSymbols()
        self.tableView.reloadData()
      }
      .store(in: &subscriptions)
  }

  func setupTableView() {
    addSubview(tableView)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.fillSuperview()
  }
}

// MARK: custom methods

extension SymbolEditorView {
  @objc func addTableRow() {
    if tableView.isEditing {
      return
    }
    // 更新database
    let lastSymbol = symbols.last ?? ""

    // 只保留一个空行
    if lastSymbol.isEmpty, !symbols.isEmpty {
      let indexPath = IndexPath(row: symbols.count - 1, section: 0)
      if let cell = tableView.cellForRow(at: indexPath), let _ = cell as? TextFieldTableViewCell {
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
      }
      return
    }

    // 先更新数据源, 在添加行
    symbols.append("")
    let indexPath = IndexPath(row: symbols.count - 1, section: 0)
    tableView.insertRows(at: [indexPath], with: .automatic)
    if let cell = tableView.cellForRow(at: indexPath), let cell = cell as? TextFieldTableViewCell {
      cell.settingItem = SettingItemModel(
        textValue: "",
        textHandled: { [unowned self] in
          symbols[indexPath.row] = $0
        }
      )
      tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
      cell.textField.becomeFirstResponder()
    }
  }
}

extension SymbolEditorView: UITableViewDataSource {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return symbols.count
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldTableViewCell.identifier, for: indexPath)
    let symbol = symbols[indexPath.row]
    guard let cell = cell as? TextFieldTableViewCell else { return cell }
    cell.settingItem = SettingItemModel(
      textValue: symbol,
      textHandled: { [unowned self] in
        symbols[indexPath.row] = $0
      }
    )
    return cell
  }

  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return "点击行可编辑"
  }

  public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    let footView = TableFooterView(footer: "点我添加新符号")
    footView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(addTableRow)))
    return footView
  }
}

extension SymbolEditorView: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    true
  }

  public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    symbols.swapAt(sourceIndexPath.row, destinationIndexPath.row)
  }

  public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
//    if let cell = tableView.cellForRow(at: indexPath), let cell = cell as? TextFieldTableViewCell {
//      cell.textField.resignFirstResponder()
//    }
    return true
  }

  public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      symbols.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .automatic)
    }
  }
}
