//
//  QuestionStep.swift
//  ACI Experience Motorsport
//
//  Created by Jacques André on 14/11/25.
//

import Foundation

/// Steps in the conversational guide's question flow.
enum QuestionStep: Int, CaseIterable {
    case epoch = 0
    
    var question: String {
        switch self {
        case .epoch: return "Qual è la tua epoca preferita?"
        }
    }
    
    var placeholder: String {
        switch self {
        case .epoch: return "Es: Mi piace il Gruppo B..."
        }
    }
    
    var icon: String {
        switch self {
        case .epoch: return "flag.checkered"
        }
    }
    
    /// Returns the next step after this one, or `nil` if the conversation is complete.
    func next(for epoch: Epoch?) -> QuestionStep? {
        return nil
    }
}
