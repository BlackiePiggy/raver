import UIKit

final class DemoAlignedTimeSeparatorCell: UICollectionViewCell {
    static let reuseIdentifier = "DemoAlignedTimeSeparatorCell"

    private let capsuleView = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        contentView.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.backgroundColor = UIColor(RaverTheme.cardBorder).withAlphaComponent(0.38)
        capsuleView.layer.cornerRadius = 9
        capsuleView.layer.masksToBounds = true
        contentView.addSubview(capsuleView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = UIColor(RaverTheme.secondaryText)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.88
        capsuleView.addSubview(label)

        NSLayoutConstraint.activate([
            capsuleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            capsuleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            capsuleView.heightAnchor.constraint(greaterThanOrEqualToConstant: 18),

            label.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: -9),
            label.topAnchor.constraint(equalTo: capsuleView.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: capsuleView.bottomAnchor, constant: -3)
        ])
    }

    func configure(text: String) {
        label.text = text
    }
}

final class DemoAlignedSystemMessageCell: UICollectionViewCell {
    static let reuseIdentifier = "DemoAlignedSystemMessageCell"

    private let capsuleView = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        contentView.layoutMargins = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.backgroundColor = UIColor(RaverTheme.cardBorder).withAlphaComponent(0.45)
        capsuleView.layer.cornerRadius = 10
        capsuleView.layer.masksToBounds = true
        contentView.addSubview(capsuleView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor(RaverTheme.secondaryText)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.88
        capsuleView.addSubview(label)

        NSLayoutConstraint.activate([
            capsuleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            capsuleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            capsuleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor),
            capsuleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),

            label.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: capsuleView.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: capsuleView.bottomAnchor, constant: -5)
        ])
    }

    func configure(text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        label.text = normalized.isEmpty ? L("[系统消息]", "[System Message]") : normalized
    }
}
