//
//  JKDesFireReaderDelegate.swift
//  JKDesFireReader
//
//  Created by Johannes Kreutz on 21.06.19.
//  Copyright © 2019 Johannes Kreutz. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// Callback interface for NFC tag detection events.
///
/// Adopt this protocol when you prefer a delegate-based approach to observing
/// session events. For reactive consumption, use ``JKDesFireReader/sessionEvents``
/// instead (or both simultaneously — they are independent).
public protocol JKDesFireReaderDelegate: AnyObject {
    /// Called on the main actor when a DesFire tag has been detected and connected.
    func didDetectDesFireTag()
    /// Called on the main actor when tag detection fails.
    func tagDetectionError(error: JKDesFirePublicError)
}
