// File: ios/Runner/GradientView.swift

import UIKit

@IBDesignable
class GradientView: UIView {
    @IBInspectable var startColor: UIColor = UIColor(red: 10/255.0, green: 30/255.0, blue: 63/255.0, alpha: 1.0) { didSet { setNeedsLayout() } }
    @IBInspectable var endColor: UIColor = UIColor(red: 223/255.0, green: 183/255.0, blue: 108/255.0, alpha: 1.0) { didSet { setNeedsLayout() } }
    
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
