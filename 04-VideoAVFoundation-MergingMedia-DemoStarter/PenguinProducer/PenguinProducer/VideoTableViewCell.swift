//
//  VideoTableViewCell.swift
//  QuickPlay
//
//  Created by Michael Briscoe on 1/5/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import UIKit

class VideoTableViewCell: UITableViewCell {
  @IBOutlet weak var clipThumbnailImageView: UIImageView!
  @IBOutlet weak var clipNameLabel: UILabel!
  
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
