//
//  JKDesFireProtocol.swift
//  JKDesFireReader
//
//  Created by Johannes Kreutz on 20.06.19.
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

// MARK: - DesFire command opcodes

enum JKDesFireCommands: UInt8 {
    case GET_MANUFACTURING_DATA  = 0x60
    case GET_APPLICATION_DIRECTORY = 0x6A
    case GET_ADDITIONAL_FRAME    = 0xAF
    case SELECT_APPLICATION      = 0x5A
    case READ_DATA               = 0xBD
    case READ_RECORD             = 0xBB
    case READ_VALUE              = 0x6C
    case GET_FILES               = 0x6F
    case GET_FILE_SETTINGS       = 0xF5
}

// MARK: - DesFire status codes returned by the tag

enum JKDesFireReturnCodes: UInt8 {
    case SUCCESS              = 0x00
    case PERMISSION_DENIED    = 0x9D
    case AUTHENTICATION_ERROR = 0xAE
    case ADDITIONAL_FRAME     = 0xAF
    case INVALID_RESPONSE     = 0x99
}
