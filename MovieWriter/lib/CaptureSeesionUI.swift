//
//  CaptureSeesionUI.swift
//  MovieWriter
//
//  Created by ZhiHua Shen on 2017/7/25.
//  Copyright © 2017年 ZhiHua Shen. All rights reserved.
//

import UIKit

class CaptureSeesionUI: UIView {

    @IBOutlet weak var topPannel: UIView!
    @IBOutlet weak var bottomPannel: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = UIColor.white.withAlphaComponent(0)
        
        topPannel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        bottomPannel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
    }

}
