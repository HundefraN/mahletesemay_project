// File: ios/Runner/GradientView.swift

import UIKit

@IBDesignable
class GradientView: UIView {
    @IBInspectable var startColor: UIColor = .blue { didSet { setNeedsLayout() } }
    @IBInspectable var endColor: UIColor = .yellow { didSet { setNeedsLayout() } }
    
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func setupGradient() {
        self.layer.insertSublayer(gradientLayer, at: 0)
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
    }
}
