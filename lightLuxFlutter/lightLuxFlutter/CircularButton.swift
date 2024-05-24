//
//  CircularButton.swift
//  lightLuxFlutter
//
//  Created by Sansi Mac on 2024/5/22.
//

import UIKit

class CircularButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        // Layer for the outer solid circle
        let outerSolidLayer = createCircleLayer(radius: bounds.width / 2, color: UIColor.clear.cgColor)
        layer.addSublayer(outerSolidLayer)

        // Layer for the inner hollow circle
        let innerRadius = bounds.width / 2 - 5
        let hollowLayer = createCircleLayer(radius: innerRadius, color: UIColor.white.cgColor)
        layer.addSublayer(hollowLayer)

        // Hollow circle should have a border to create the hollow effect
        hollowLayer.fillColor = UIColor.clear.cgColor
        hollowLayer.lineWidth = 3 // Set to 2 * 5 for hollow effect
//        hollowLayer.strokeColor = UIColor.white.cgColor
        hollowLayer.strokeColor = UIColor(red: 0/255, green: 78/255, blue: 162/255, alpha: 1.0).cgColor

        // Layer for the innermost solid circle
        let centerRadius = innerRadius - 4
//        let centerSolidLayer = createCircleLayer(radius: centerRadius, color: CGColor(red: 0/255, green: 78/255, blue: 162/255, alpha: 1.0))
        let centerSolidLayer = createCircleLayer(radius: centerRadius, color: UIColor(red: 0/255, green: 78/255, blue: 162/255, alpha: 1.0).cgColor)
        layer.addSublayer(centerSolidLayer)
    }

    private func createCircleLayer(radius: CGFloat, color: CGColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: bounds.width / 2, y: bounds.height / 2), radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        layer.path = circularPath.cgPath
        layer.fillColor = color
        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = true
    }
}
