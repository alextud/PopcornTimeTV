//
//  RotateAnimation.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 25.06.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI

struct RotateAnimation: ViewModifier {
    @State var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isAnimating ? 360.0 : 0))
            .animation(.linear(duration: 1.0)
                            .repeatForever(autoreverses: false),
                      value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

struct RotateAnimation_Previews: PreviewProvider {
    static var previews: some View {
        Image("Download Progress Indeterminate")
            .previewLayout(.sizeThatFits)
            .modifier(RotateAnimation())
    }
}
