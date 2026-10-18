import Foundation
import Shared

/// Turns the finished contribute screens into the shared v2 payload.
enum ContributeFlowBridge {
    static func assemble(
        placeId: String,
        submissionId: String,
        wheelchair: Bool,
        entrances: [EntrancePassDraft],
        elevators: [ElevatorPassDraft],
        toilets: [ToiletPassDraft],
        pathwayNotices: Set<String>,
        pathwayPhotos: [ReviewPhotoDraft],
        seatingAnswer: String?,
        seatingPhotos: [ReviewPhotoDraft],
        parkingAnswer: String?,
        parkingPhotos: [ReviewPhotoDraft],
        categoryNotes: [String: String]
    ) -> AssembledContribution {
        let builder = ContributionBuilder(placeId: placeId, submissionId: submissionId)
        builder.setPersona(wheelchair: wheelchair)
        for pass in entrances {
            builder.addEntrancePass(
                photos: pass.sectionPhotos.map(kotlinPhoto),
                lobby: pass.locations.contains(.lobby),
                basement: pass.locations.contains(.basement),
                lobbyTags: pass.lobbyTags.map(\.label),
                basementTags: pass.basementTags.map(\.label),
                lobbyRamp: pass.lobbyRampAnswer,
                basementRamp: pass.basementRampAnswer,
                lobbyHandrail: pass.lobbyHandrailAnswer,
                basementHandrail: pass.basementHandrailAnswer,
                lobbyRampPhotos: pass.lobbyRampPhotos.map(kotlinPhoto),
                lobbyHandrailPhotos: pass.lobbyHandrailPhotos.map(kotlinPhoto),
                basementRampPhotos: pass.basementRampPhotos.map(kotlinPhoto),
                basementHandrailPhotos: pass.basementHandrailPhotos.map(kotlinPhoto)
            )
        }
        for pass in elevators {
            var answers: [String: String] = [:]
            for (question, answer) in pass.answers {
                answers[question.rawValue] = answer
            }
            builder.addElevatorPass(
                answers: answers,
                photos: pass.photos.map(kotlinPhoto),
                location: pass.location,
                widePhotos: (pass.evidence[.wideEntrance] ?? []).map(kotlinPhoto),
                spacePhotos: (pass.evidence[.spaceToManeuver] ?? []).map(kotlinPhoto),
                buttonPhotos: (pass.evidence[.reachableButtons] ?? []).map(kotlinPhoto)
            )
        }
        for pass in toilets {
            var answers: [String: String] = [:]
            for (question, answer) in pass.answers {
                answers[question.rawValue] = answer
            }
            builder.addToiletPass(
                answers: answers,
                photos: pass.photos.map(kotlinPhoto),
                location: pass.location,
                seatPhotos: (pass.evidence[.seat] ?? []).map(kotlinPhoto),
                grabPhotos: (pass.evidence[.grabBars] ?? []).map(kotlinPhoto),
                spacePhotos: (pass.evidence[.space] ?? []).map(kotlinPhoto),
                sinkPhotos: (pass.evidence[.sink] ?? []).map(kotlinPhoto),
                emergencyPhotos: (pass.evidence[.emergency] ?? []).map(kotlinPhoto)
            )
        }
        if !pathwayNotices.isEmpty {
            builder.setPathways(notices: Array(pathwayNotices), photos: pathwayPhotos.map(kotlinPhoto))
        }
        if let seatingAnswer {
            builder.setSeating(answer: seatingAnswer, photos: seatingPhotos.map(kotlinPhoto))
        }
        if let parkingAnswer {
            builder.setParking(answer: parkingAnswer, photos: parkingPhotos.map(kotlinPhoto))
        }
        for (raw, text) in categoryNotes {
            guard let category = sharedCategory(raw) else { continue }
            builder.setCategoryNote(category: category, text: text)
        }
        return builder.build()
    }

    private static func sharedCategory(_ raw: String) -> Shared.ContributeReviewCategory? {
        switch raw {
        case "entrance": .entrance
        case "elevator": .elevator
        case "toilet": .toilet
        case "outdoorPathways": .outdoorPathways
        case "seating": .seating
        case "parking": .parking
        default: nil
        }
    }
}

private func kotlinPhoto(_ photo: ReviewPhotoDraft) -> LocalReviewPhoto {
    LocalReviewPhoto(fileId: photo.id.uuidString, jpeg: photo.jpegData.asKotlinByteArray(), caption: photo.caption)
}
