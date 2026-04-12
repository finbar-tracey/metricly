import Foundation

struct ExerciseGuide: Identifiable {
    let id = UUID()
    let name: String
    let aliases: [String]
    let category: MuscleGroup
    let description: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let formTips: [String]
    let commonMistakes: [String]

    /// Case-insensitive lookup. Returns the first guide whose name or aliases match.
    static func find(_ exerciseName: String) -> ExerciseGuide? {
        let query = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return nil }

        // 1. Exact match on canonical name
        if let exact = database.first(where: { $0.name.lowercased() == query }) {
            return exact
        }

        // 2. Exact match on alias
        if let aliasMatch = database.first(where: { guide in
            guide.aliases.contains { $0.lowercased() == query }
        }) {
            return aliasMatch
        }

        // 3. Substring match (query contains name or name contains query)
        if let substring = database.first(where: { guide in
            let canonical = guide.name.lowercased()
            return query.contains(canonical) || canonical.contains(query)
        }) {
            return substring
        }

        return nil
    }
}

// MARK: - Database

extension ExerciseGuide {
    static let database: [ExerciseGuide] = [

        // MARK: Chest

        ExerciseGuide(
            name: "Bench Press",
            aliases: ["Barbell Bench Press", "Flat Bench Press", "BB Bench Press", "Flat Bench"],
            category: .chest,
            description: "A fundamental compound press performed lying on a flat bench, pushing a barbell from chest level to full arm extension.",
            primaryMuscles: ["Pectoralis Major", "Anterior Deltoid", "Triceps"],
            secondaryMuscles: ["Serratus Anterior"],
            formTips: [
                "Retract and depress your shoulder blades before unracking",
                "Plant feet flat on the floor and maintain a slight arch in the lower back",
                "Lower the bar to mid-chest with elbows at roughly 45 degrees",
                "Drive through your feet and press the bar back over your shoulders"
            ],
            commonMistakes: [
                "Flaring elbows to 90 degrees, which stresses the shoulders",
                "Bouncing the bar off the chest instead of controlling the descent",
                "Lifting hips off the bench during the press"
            ]
        ),
        ExerciseGuide(
            name: "Dumbbell Bench Press",
            aliases: ["DB Bench Press", "Flat Dumbbell Press", "Flat DB Press"],
            category: .chest,
            description: "A pressing movement using dumbbells on a flat bench, allowing greater range of motion than the barbell version.",
            primaryMuscles: ["Pectoralis Major", "Anterior Deltoid", "Triceps"],
            secondaryMuscles: ["Serratus Anterior", "Biceps (stabilizer)"],
            formTips: [
                "Start with dumbbells at chest height, palms facing forward",
                "Press up and slightly inward so the dumbbells nearly touch at the top",
                "Lower under control to get a deep stretch at the bottom",
                "Keep your wrists stacked directly over your elbows"
            ],
            commonMistakes: [
                "Using momentum to swing the dumbbells up",
                "Letting the dumbbells drift too far apart at the bottom",
                "Not controlling the negative portion of the lift"
            ]
        ),
        ExerciseGuide(
            name: "Incline Bench Press",
            aliases: ["Incline Barbell Press", "Incline BB Press"],
            category: .chest,
            description: "A bench press performed at a 30-45 degree incline to emphasize the upper chest and front delts.",
            primaryMuscles: ["Upper Pectoralis Major", "Anterior Deltoid", "Triceps"],
            secondaryMuscles: ["Serratus Anterior"],
            formTips: [
                "Set the bench to 30-45 degrees for optimal upper chest activation",
                "Unrack and lower the bar to the upper chest or clavicle area",
                "Keep shoulder blades retracted throughout the movement",
                "Press the bar up and slightly back toward the rack path"
            ],
            commonMistakes: [
                "Setting the incline too steep, turning it into a shoulder press",
                "Losing the shoulder blade retraction as you press",
                "Flaring the elbows excessively wide"
            ]
        ),
        ExerciseGuide(
            name: "Incline Dumbbell Press",
            aliases: ["Incline DB Press"],
            category: .chest,
            description: "An incline pressing movement using dumbbells for greater range of motion and independent arm work.",
            primaryMuscles: ["Upper Pectoralis Major", "Anterior Deltoid", "Triceps"],
            secondaryMuscles: ["Serratus Anterior"],
            formTips: [
                "Set the bench to 30-45 degrees",
                "Start with dumbbells at shoulder height, palms forward",
                "Press up and slightly inward, squeezing at the top",
                "Lower slowly to get a full stretch in the upper chest"
            ],
            commonMistakes: [
                "Using a bench angle that is too steep",
                "Letting the lower back overarch off the bench",
                "Rushing the eccentric phase"
            ]
        ),
        ExerciseGuide(
            name: "Cable Fly",
            aliases: ["Cable Chest Fly", "Cable Crossover", "Cable Flye"],
            category: .chest,
            description: "An isolation exercise using cables to target the chest through a wide arc-like motion with constant tension.",
            primaryMuscles: ["Pectoralis Major"],
            secondaryMuscles: ["Anterior Deltoid", "Biceps (stabilizer)"],
            formTips: [
                "Set the pulleys to shoulder height for mid-chest emphasis",
                "Step forward slightly and maintain a small bend in the elbows",
                "Bring hands together in front of your chest in a hugging motion",
                "Squeeze the chest hard at the end position and control the return"
            ],
            commonMistakes: [
                "Using too much weight and turning it into a pressing motion",
                "Straightening the arms completely, stressing the elbow joint",
                "Leaning too far forward and losing balance"
            ]
        ),
        ExerciseGuide(
            name: "Dumbbell Fly",
            aliases: ["Dumbbell Flye", "DB Fly", "Flat Fly", "Chest Fly"],
            category: .chest,
            description: "An isolation exercise lying on a flat bench, lowering dumbbells in a wide arc to stretch and contract the chest.",
            primaryMuscles: ["Pectoralis Major"],
            secondaryMuscles: ["Anterior Deltoid", "Biceps (stabilizer)"],
            formTips: [
                "Keep a slight bend in the elbows throughout the entire movement",
                "Lower the dumbbells in a wide arc until you feel a stretch in the chest",
                "Focus on squeezing the chest to bring the weights back together",
                "Use lighter weight than pressing — this is an isolation exercise"
            ],
            commonMistakes: [
                "Going too heavy and bending the arms into a press",
                "Lowering the dumbbells too far below chest level",
                "Losing the elbow angle during the movement"
            ]
        ),
        ExerciseGuide(
            name: "Machine Chest Press",
            aliases: ["Chest Press Machine", "Seated Chest Press"],
            category: .chest,
            description: "A machine-based pressing movement that provides a fixed path, ideal for beginners or high-rep finishing sets.",
            primaryMuscles: ["Pectoralis Major", "Anterior Deltoid", "Triceps"],
            secondaryMuscles: ["Serratus Anterior"],
            formTips: [
                "Adjust the seat so the handles are at mid-chest height",
                "Keep your back flat against the pad and shoulder blades retracted",
                "Press forward to full extension without locking the elbows",
                "Control the weight on the return — don't let the stack slam"
            ],
            commonMistakes: [
                "Setting the seat too high or too low",
                "Letting the shoulders roll forward off the pad",
                "Using momentum instead of controlled movement"
            ]
        ),
        ExerciseGuide(
            name: "Push-Up",
            aliases: ["Push Up", "Pushup", "Press-Up"],
            category: .chest,
            description: "A bodyweight exercise pressing the body up from the floor, targeting the chest, shoulders, and triceps.",
            primaryMuscles: ["Pectoralis Major", "Anterior Deltoid", "Triceps"],
            secondaryMuscles: ["Core", "Serratus Anterior"],
            formTips: [
                "Keep your body in a straight line from head to heels",
                "Place hands slightly wider than shoulder-width apart",
                "Lower until your chest nearly touches the floor",
                "Push up explosively while maintaining core tension"
            ],
            commonMistakes: [
                "Letting the hips sag or pike up",
                "Only performing partial range of motion",
                "Flaring the elbows out to 90 degrees"
            ]
        ),
        ExerciseGuide(
            name: "Floor Press",
            aliases: ["Barbell Floor Press"],
            category: .chest,
            description: "A bench press performed lying on the floor, limiting range of motion and emphasizing lockout strength.",
            primaryMuscles: ["Pectoralis Major", "Triceps", "Anterior Deltoid"],
            secondaryMuscles: ["Serratus Anterior"],
            formTips: [
                "Lie flat on the floor with knees bent and feet flat",
                "Lower the bar until your upper arms rest briefly on the floor",
                "Pause on the floor to eliminate the stretch reflex",
                "Press up powerfully — this builds lockout strength"
            ],
            commonMistakes: [
                "Bouncing the elbows off the floor",
                "Using leg drive which defeats the purpose",
                "Not pausing at the bottom"
            ]
        ),
        ExerciseGuide(
            name: "Pec Deck",
            aliases: ["Pec Deck Machine", "Machine Fly", "Pec Fly Machine"],
            category: .chest,
            description: "A machine-based chest isolation exercise mimicking the fly motion with guided pads or handles.",
            primaryMuscles: ["Pectoralis Major"],
            secondaryMuscles: ["Anterior Deltoid"],
            formTips: [
                "Adjust the seat so the handles or pads are at chest height",
                "Keep a slight bend in the elbows and press the pads together",
                "Squeeze the chest hard at the fully contracted position",
                "Return slowly and control the stretch"
            ],
            commonMistakes: [
                "Going too heavy and using the shoulders to drive the movement",
                "Not getting a full range of motion on the stretch",
                "Rounding the shoulders forward"
            ]
        ),

        // MARK: Back

        ExerciseGuide(
            name: "Barbell Row",
            aliases: ["Bent Over Row", "BB Row", "Bent Over Barbell Row"],
            category: .back,
            description: "A compound pulling movement performed bent over, rowing a barbell toward the lower chest or upper abdomen.",
            primaryMuscles: ["Latissimus Dorsi", "Rhomboids", "Trapezius"],
            secondaryMuscles: ["Biceps", "Rear Deltoid", "Erector Spinae"],
            formTips: [
                "Hinge at the hips to roughly 45 degrees with a flat back",
                "Pull the bar toward your lower chest or upper abs",
                "Squeeze your shoulder blades together at the top",
                "Lower the bar under control — don't let it drop"
            ],
            commonMistakes: [
                "Rounding the lower back during the movement",
                "Using excessive body English to heave the weight",
                "Pulling to the wrong position (too high or too low)"
            ]
        ),
        ExerciseGuide(
            name: "Dumbbell Row",
            aliases: ["One Arm Dumbbell Row", "DB Row", "Single Arm Row"],
            category: .back,
            description: "A unilateral rowing movement using one dumbbell at a time, allowing you to address side-to-side imbalances.",
            primaryMuscles: ["Latissimus Dorsi", "Rhomboids", "Trapezius"],
            secondaryMuscles: ["Biceps", "Rear Deltoid"],
            formTips: [
                "Place one hand and knee on a bench for support",
                "Row the dumbbell toward your hip, leading with the elbow",
                "Keep your torso parallel to the floor and avoid rotating",
                "Squeeze the lat at the top and lower with control"
            ],
            commonMistakes: [
                "Rotating the torso to heave the weight up",
                "Pulling with the bicep instead of driving the elbow back",
                "Not getting a full stretch at the bottom"
            ]
        ),
        ExerciseGuide(
            name: "Cable Row",
            aliases: ["Seated Cable Row", "Seated Row"],
            category: .back,
            description: "A seated pulling exercise using a cable machine, providing constant tension through the full range of motion.",
            primaryMuscles: ["Latissimus Dorsi", "Rhomboids", "Trapezius"],
            secondaryMuscles: ["Biceps", "Rear Deltoid"],
            formTips: [
                "Sit upright with a slight forward lean at the start",
                "Pull the handle toward your lower chest or upper abdomen",
                "Squeeze your shoulder blades together and hold briefly",
                "Return with control — don't let the weight yank you forward"
            ],
            commonMistakes: [
                "Excessive swinging of the torso back and forth",
                "Shrugging the shoulders up instead of pulling back",
                "Rounding the back at the stretched position"
            ]
        ),
        ExerciseGuide(
            name: "T-Bar Row",
            aliases: ["T Bar Row", "Landmine Row"],
            category: .back,
            description: "A compound row using a barbell anchored at one end, allowing heavy loading with a neutral grip.",
            primaryMuscles: ["Latissimus Dorsi", "Rhomboids", "Trapezius"],
            secondaryMuscles: ["Biceps", "Rear Deltoid", "Erector Spinae"],
            formTips: [
                "Straddle the bar and grip the handle with both hands",
                "Keep your chest up and back flat throughout",
                "Pull the weight toward your upper abdomen",
                "Squeeze hard at the top before lowering"
            ],
            commonMistakes: [
                "Rounding the upper back to lift heavier",
                "Standing too upright, reducing back activation",
                "Jerking the weight up with momentum"
            ]
        ),
        ExerciseGuide(
            name: "Pendlay Row",
            aliases: ["Strict Barbell Row"],
            category: .back,
            description: "A strict barbell row where the bar returns to the floor between each rep, eliminating momentum.",
            primaryMuscles: ["Latissimus Dorsi", "Rhomboids", "Trapezius"],
            secondaryMuscles: ["Biceps", "Rear Deltoid", "Erector Spinae"],
            formTips: [
                "Start with the bar on the floor, torso parallel to the ground",
                "Explosively row the bar to your lower chest",
                "Return the bar to the floor completely between each rep",
                "Keep your back flat and core braced throughout"
            ],
            commonMistakes: [
                "Not lowering the bar all the way to the floor",
                "Raising the torso to cheat the weight up",
                "Losing back position as fatigue sets in"
            ]
        ),
        ExerciseGuide(
            name: "Chest Supported Row",
            aliases: ["Incline DB Row", "Chest Supported Dumbbell Row", "Seal Row"],
            category: .back,
            description: "A rowing variation with the chest against an incline bench, eliminating lower back stress and body English.",
            primaryMuscles: ["Latissimus Dorsi", "Rhomboids", "Trapezius"],
            secondaryMuscles: ["Biceps", "Rear Deltoid"],
            formTips: [
                "Lie face down on a 30-45 degree incline bench",
                "Let the dumbbells hang straight down, then row them up",
                "Squeeze the shoulder blades together at the top",
                "This eliminates cheating — use strict form"
            ],
            commonMistakes: [
                "Lifting the chest off the bench to cheat",
                "Not getting a full stretch at the bottom",
                "Going too heavy and losing the squeeze at the top"
            ]
        ),
        ExerciseGuide(
            name: "Lat Pulldown",
            aliases: ["Wide Grip Pulldown", "Cable Pulldown"],
            category: .back,
            description: "A vertical pulling exercise on a cable machine, targeting the lats by pulling a bar down to chest level.",
            primaryMuscles: ["Latissimus Dorsi", "Teres Major"],
            secondaryMuscles: ["Biceps", "Rhomboids", "Rear Deltoid"],
            formTips: [
                "Grip the bar slightly wider than shoulder width",
                "Lean back slightly and pull the bar to your upper chest",
                "Drive your elbows down and back, squeezing the lats",
                "Control the bar on the way up — get a full stretch"
            ],
            commonMistakes: [
                "Pulling the bar behind the neck, which strains the shoulders",
                "Leaning too far back and turning it into a row",
                "Using momentum and swinging the torso"
            ]
        ),
        ExerciseGuide(
            name: "Pull-Up",
            aliases: ["Pullup", "Pull Up"],
            category: .back,
            description: "A bodyweight vertical pull using an overhand grip, one of the best exercises for building back width.",
            primaryMuscles: ["Latissimus Dorsi", "Teres Major"],
            secondaryMuscles: ["Biceps", "Rhomboids", "Core"],
            formTips: [
                "Grip the bar overhand, slightly wider than shoulder width",
                "Start from a dead hang with arms fully extended",
                "Pull until your chin clears the bar, driving elbows down",
                "Lower under control back to a full dead hang"
            ],
            commonMistakes: [
                "Kipping or swinging to get over the bar",
                "Not using full range of motion (partial reps)",
                "Shrugging the shoulders instead of engaging the lats"
            ]
        ),
        ExerciseGuide(
            name: "Chin-Up",
            aliases: ["Chinup", "Chin Up"],
            category: .back,
            description: "A bodyweight vertical pull using an underhand grip, adding more bicep involvement than the pull-up.",
            primaryMuscles: ["Latissimus Dorsi", "Biceps"],
            secondaryMuscles: ["Teres Major", "Rhomboids", "Core"],
            formTips: [
                "Grip the bar underhand at shoulder width",
                "Start from a dead hang and pull your chin above the bar",
                "Focus on driving the elbows down toward your hips",
                "Lower all the way down to a full stretch"
            ],
            commonMistakes: [
                "Not going through full range of motion",
                "Crossing the legs and swinging for momentum",
                "Only using the arms instead of engaging the back"
            ]
        ),
        ExerciseGuide(
            name: "Close Grip Pulldown",
            aliases: ["Close Grip Lat Pulldown", "V-Bar Pulldown"],
            category: .back,
            description: "A lat pulldown using a narrow V-bar attachment, emphasizing the lower lats and adding more bicep work.",
            primaryMuscles: ["Latissimus Dorsi", "Biceps"],
            secondaryMuscles: ["Teres Major", "Rhomboids"],
            formTips: [
                "Use a V-bar or close grip handle attachment",
                "Lean back slightly and pull the handle to your upper chest",
                "Squeeze your lats hard at the bottom of the pull",
                "Extend your arms fully at the top for a complete stretch"
            ],
            commonMistakes: [
                "Using too much body momentum",
                "Not getting a full stretch at the top",
                "Pulling with just the arms instead of the back"
            ]
        ),

        // MARK: Shoulders

        ExerciseGuide(
            name: "Overhead Press",
            aliases: ["OHP", "Military Press", "Barbell Shoulder Press", "Standing Press"],
            category: .shoulders,
            description: "A compound vertical pressing movement pushing a barbell from shoulder level to overhead.",
            primaryMuscles: ["Anterior Deltoid", "Lateral Deltoid", "Triceps"],
            secondaryMuscles: ["Upper Trapezius", "Core", "Serratus Anterior"],
            formTips: [
                "Start with the bar at the front of your shoulders, grip just outside shoulder width",
                "Brace your core and glutes, then press straight up",
                "Move your head slightly back to clear the bar path, then forward once it passes",
                "Lock out overhead with the bar directly over your mid-foot"
            ],
            commonMistakes: [
                "Excessive lower back arching to compensate for weak shoulders",
                "Pressing the bar out in front instead of straight up",
                "Not bracing the core, leading to energy leaks"
            ]
        ),
        ExerciseGuide(
            name: "Dumbbell Shoulder Press",
            aliases: ["DB Shoulder Press", "Seated Dumbbell Press", "Seated DB Press"],
            category: .shoulders,
            description: "A pressing movement using dumbbells, allowing independent arm work and a greater range of motion.",
            primaryMuscles: ["Anterior Deltoid", "Lateral Deltoid", "Triceps"],
            secondaryMuscles: ["Upper Trapezius", "Serratus Anterior"],
            formTips: [
                "Start with dumbbells at ear height, palms facing forward",
                "Press straight up until arms are fully extended",
                "Lower under control back to the starting position",
                "Keep your core tight and back against the bench if seated"
            ],
            commonMistakes: [
                "Arching the back excessively",
                "Not lowering the dumbbells far enough",
                "Using leg drive to push past sticking points"
            ]
        ),
        ExerciseGuide(
            name: "Arnold Press",
            aliases: ["Arnold Dumbbell Press"],
            category: .shoulders,
            description: "A dumbbell press variation that rotates the palms during the movement, hitting all three deltoid heads.",
            primaryMuscles: ["Anterior Deltoid", "Lateral Deltoid", "Triceps"],
            secondaryMuscles: ["Rear Deltoid", "Upper Trapezius"],
            formTips: [
                "Start with palms facing you at chest height (like the top of a curl)",
                "Rotate your palms outward as you press up overhead",
                "At the top, palms should face forward like a standard press",
                "Reverse the rotation on the way down"
            ],
            commonMistakes: [
                "Rushing the rotation instead of keeping it smooth",
                "Using too much weight and losing the rotation pattern",
                "Not rotating fully through the range of motion"
            ]
        ),
        ExerciseGuide(
            name: "Lateral Raise",
            aliases: ["Side Raise", "Side Lateral Raise", "Dumbbell Lateral Raise"],
            category: .shoulders,
            description: "An isolation exercise lifting dumbbells out to the sides to target the lateral (side) deltoid.",
            primaryMuscles: ["Lateral Deltoid"],
            secondaryMuscles: ["Anterior Deltoid", "Upper Trapezius"],
            formTips: [
                "Keep a slight bend in the elbows throughout",
                "Raise the dumbbells out to the sides until arms are parallel to the floor",
                "Lead with the elbows, not the hands — think of pouring water from a pitcher",
                "Lower slowly under control, don't just drop them"
            ],
            commonMistakes: [
                "Swinging the weights up with momentum",
                "Shrugging the traps to lift the weight instead of using the delts",
                "Raising the arms higher than parallel, shifting tension to the traps"
            ]
        ),
        ExerciseGuide(
            name: "Cable Lateral Raise",
            aliases: ["Single Arm Cable Lateral Raise"],
            category: .shoulders,
            description: "A lateral raise using a cable for constant tension throughout the range of motion.",
            primaryMuscles: ["Lateral Deltoid"],
            secondaryMuscles: ["Anterior Deltoid", "Upper Trapezius"],
            formTips: [
                "Stand sideways to the cable with the handle in the far hand",
                "Keep a slight bend in the elbow and raise to shoulder height",
                "The cable provides tension even at the bottom, so control the whole range",
                "Lower slowly — the cable resists the entire way down"
            ],
            commonMistakes: [
                "Standing too close to the machine",
                "Using the whole body to swing the weight",
                "Going too heavy and compensating with traps"
            ]
        ),
        ExerciseGuide(
            name: "Face Pull",
            aliases: ["Cable Face Pull", "Rope Face Pull"],
            category: .shoulders,
            description: "A cable pulling exercise targeting the rear delts and external rotators, essential for shoulder health.",
            primaryMuscles: ["Rear Deltoid", "Rhomboids", "External Rotators"],
            secondaryMuscles: ["Middle Trapezius", "Biceps"],
            formTips: [
                "Set the cable at upper chest or face height with a rope attachment",
                "Pull the rope toward your face, splitting the ends apart",
                "Externally rotate your shoulders so your fists end up beside your ears",
                "Squeeze the rear delts and hold briefly at the end position"
            ],
            commonMistakes: [
                "Setting the cable too low, turning it into a row",
                "Not splitting the rope apart enough at the end",
                "Leaning back and using body weight to pull"
            ]
        ),
        ExerciseGuide(
            name: "Upright Row",
            aliases: ["Barbell Upright Row", "Dumbbell Upright Row"],
            category: .shoulders,
            description: "A pulling movement raising the bar or dumbbells along the front of the body to chin height.",
            primaryMuscles: ["Lateral Deltoid", "Upper Trapezius"],
            secondaryMuscles: ["Anterior Deltoid", "Biceps"],
            formTips: [
                "Use a grip slightly wider than shoulder width to reduce shoulder impingement risk",
                "Pull the weight up to about chin height, leading with the elbows",
                "Keep the bar or dumbbells close to your body throughout",
                "Lower under control"
            ],
            commonMistakes: [
                "Using too narrow a grip, which can cause shoulder impingement",
                "Pulling the weight too high above the shoulders",
                "Swinging the body to generate momentum"
            ]
        ),
        ExerciseGuide(
            name: "Reverse Fly",
            aliases: ["Rear Delt Fly", "Reverse Dumbbell Fly", "Bent Over Fly"],
            category: .shoulders,
            description: "An isolation exercise for the rear delts, performed bent over or on a machine.",
            primaryMuscles: ["Rear Deltoid"],
            secondaryMuscles: ["Rhomboids", "Middle Trapezius"],
            formTips: [
                "Bend forward at the hips with a flat back",
                "Raise the dumbbells out to the sides with slightly bent elbows",
                "Squeeze the shoulder blades together at the top",
                "Use light weight and focus on the mind-muscle connection"
            ],
            commonMistakes: [
                "Going too heavy and using momentum",
                "Rounding the back during the movement",
                "Not squeezing at the top of the range"
            ]
        ),
        ExerciseGuide(
            name: "Landmine Press",
            aliases: ["Single Arm Landmine Press"],
            category: .shoulders,
            description: "A pressing variation using one end of a barbell anchored to the floor, providing a unique arc pressing path.",
            primaryMuscles: ["Anterior Deltoid", "Upper Pectoralis Major", "Triceps"],
            secondaryMuscles: ["Core", "Serratus Anterior"],
            formTips: [
                "Hold the end of the barbell at shoulder height with one hand",
                "Press up and forward following the natural arc of the bar",
                "Keep your core braced to prevent rotation",
                "Lower with control back to the starting position"
            ],
            commonMistakes: [
                "Leaning back too far and turning it into an incline press",
                "Not bracing the core, allowing the torso to rotate",
                "Using too narrow a stance for stability"
            ]
        ),

        // MARK: Biceps

        ExerciseGuide(
            name: "Barbell Curl",
            aliases: ["BB Curl", "Standing Barbell Curl"],
            category: .biceps,
            description: "The classic bicep exercise, curling a straight barbell from hip level to shoulder height.",
            primaryMuscles: ["Biceps Brachii"],
            secondaryMuscles: ["Brachialis", "Forearms"],
            formTips: [
                "Stand with feet shoulder-width apart, arms fully extended",
                "Curl the bar up by bending at the elbows only",
                "Keep your upper arms pinned to your sides throughout",
                "Lower the bar slowly under control to full extension"
            ],
            commonMistakes: [
                "Swinging the body and using momentum to curl the weight",
                "Moving the elbows forward during the curl",
                "Not lowering the bar fully at the bottom"
            ]
        ),
        ExerciseGuide(
            name: "Dumbbell Curl",
            aliases: ["DB Curl", "Standing Dumbbell Curl", "Bicep Curl"],
            category: .biceps,
            description: "A unilateral or bilateral curling movement using dumbbells, allowing supination through the range of motion.",
            primaryMuscles: ["Biceps Brachii"],
            secondaryMuscles: ["Brachialis", "Forearms"],
            formTips: [
                "Start with palms facing your thighs, supinate as you curl up",
                "Keep your elbows locked at your sides throughout the movement",
                "Squeeze the bicep hard at the top of the curl",
                "Lower under control — don't let gravity do the work"
            ],
            commonMistakes: [
                "Swinging the weight with body momentum",
                "Cutting the range of motion short at the bottom",
                "Alternating too fast and losing control"
            ]
        ),
        ExerciseGuide(
            name: "Hammer Curl",
            aliases: ["DB Hammer Curl", "Dumbbell Hammer Curl"],
            category: .biceps,
            description: "A curl variation with a neutral (palms facing each other) grip, targeting both the biceps and brachialis.",
            primaryMuscles: ["Brachialis", "Biceps Brachii"],
            secondaryMuscles: ["Brachioradialis", "Forearms"],
            formTips: [
                "Hold dumbbells with a neutral grip (palms facing each other)",
                "Curl up while maintaining the neutral grip throughout",
                "Keep elbows pinned at your sides",
                "Works the brachialis which pushes the bicep peak higher"
            ],
            commonMistakes: [
                "Letting the wrists rotate during the curl",
                "Swinging the torso for momentum",
                "Not using full range of motion"
            ]
        ),
        ExerciseGuide(
            name: "Preacher Curl",
            aliases: ["Preacher Bench Curl", "EZ Bar Preacher Curl"],
            category: .biceps,
            description: "A curl performed on a preacher bench that isolates the biceps by eliminating momentum and body swing.",
            primaryMuscles: ["Biceps Brachii"],
            secondaryMuscles: ["Brachialis"],
            formTips: [
                "Sit with your armpits snug against the top of the pad",
                "Extend your arms fully at the bottom to get a complete stretch",
                "Curl up without lifting your arms off the pad",
                "Control the negative — the stretch position is where injuries happen"
            ],
            commonMistakes: [
                "Lifting the elbows off the pad to cheat the weight up",
                "Dropping the weight too fast on the eccentric",
                "Not going through full range of motion"
            ]
        ),
        ExerciseGuide(
            name: "Cable Curl",
            aliases: ["Cable Bicep Curl", "Standing Cable Curl"],
            category: .biceps,
            description: "A bicep curl using a cable machine for constant tension through the entire range of motion.",
            primaryMuscles: ["Biceps Brachii"],
            secondaryMuscles: ["Brachialis", "Forearms"],
            formTips: [
                "Stand facing the low pulley with an appropriate attachment",
                "Keep your elbows at your sides and curl the handle up",
                "Squeeze the biceps at the top of the movement",
                "Lower slowly — the cable resists the entire way down"
            ],
            commonMistakes: [
                "Standing too close to the machine",
                "Swinging the body to generate momentum",
                "Letting the elbows drift forward"
            ]
        ),
        ExerciseGuide(
            name: "Incline Curl",
            aliases: ["Incline Dumbbell Curl", "Incline DB Curl"],
            category: .biceps,
            description: "A curl performed on an incline bench, placing the biceps in a stretched position for greater activation.",
            primaryMuscles: ["Biceps Brachii (long head)"],
            secondaryMuscles: ["Brachialis"],
            formTips: [
                "Set the bench to 45-60 degrees and sit back with arms hanging",
                "Let your arms hang straight down for a full stretch",
                "Curl up without moving your upper arms forward",
                "This targets the long head of the biceps due to the stretch"
            ],
            commonMistakes: [
                "Bringing the elbows forward during the curl",
                "Using momentum by swinging off the bench",
                "Not going to full extension at the bottom"
            ]
        ),
        ExerciseGuide(
            name: "EZ Bar Curl",
            aliases: ["EZ Curl", "EZ Barbell Curl"],
            category: .biceps,
            description: "A curl using an angled EZ bar that reduces wrist strain while targeting the biceps.",
            primaryMuscles: ["Biceps Brachii"],
            secondaryMuscles: ["Brachialis", "Forearms"],
            formTips: [
                "Grip the angled portions of the bar for a natural wrist angle",
                "Keep upper arms stationary and curl by bending the elbows",
                "Squeeze at the top and lower with control",
                "The angled grip is easier on the wrists than a straight bar"
            ],
            commonMistakes: [
                "Using body swing to get the weight up",
                "Gripping the wrong part of the bar",
                "Rushing the reps and losing the squeeze"
            ]
        ),
        ExerciseGuide(
            name: "Concentration Curl",
            aliases: ["Seated Concentration Curl"],
            category: .biceps,
            description: "A seated single-arm curl with the elbow braced against the inner thigh for maximum isolation.",
            primaryMuscles: ["Biceps Brachii"],
            secondaryMuscles: ["Brachialis"],
            formTips: [
                "Sit on a bench and brace your elbow against your inner thigh",
                "Let the dumbbell hang at full arm extension",
                "Curl up while keeping your upper arm completely stationary",
                "Squeeze hard at the top and lower slowly"
            ],
            commonMistakes: [
                "Lifting the elbow off the thigh to cheat",
                "Leaning back to swing the weight up",
                "Rushing through the repetitions"
            ]
        ),

        // MARK: Triceps

        ExerciseGuide(
            name: "Tricep Pushdown",
            aliases: ["Cable Pushdown", "Rope Pushdown", "Tricep Pressdown"],
            category: .triceps,
            description: "A cable isolation exercise pushing the handle down to work the triceps, particularly the lateral head.",
            primaryMuscles: ["Triceps (lateral head)", "Triceps (medial head)"],
            secondaryMuscles: ["Forearms"],
            formTips: [
                "Stand upright with elbows pinned at your sides",
                "Push the handle down until your arms are fully extended",
                "Squeeze the triceps hard at the bottom",
                "Return under control — don't let the weight stack yank your arms up"
            ],
            commonMistakes: [
                "Flaring the elbows out or letting them drift forward",
                "Leaning over the handle and using body weight",
                "Not achieving full lockout at the bottom"
            ]
        ),
        ExerciseGuide(
            name: "Overhead Tricep Extension",
            aliases: ["Overhead Extension", "Tricep Overhead Extension", "French Press"],
            category: .triceps,
            description: "A tricep exercise performed overhead, emphasizing the long head of the triceps through a full stretch.",
            primaryMuscles: ["Triceps (long head)"],
            secondaryMuscles: ["Triceps (lateral head)", "Triceps (medial head)"],
            formTips: [
                "Hold a dumbbell or cable overhead with arms extended",
                "Lower the weight behind your head by bending the elbows",
                "Keep your upper arms close to your ears throughout",
                "Extend back to the top, squeezing the triceps"
            ],
            commonMistakes: [
                "Flaring the elbows out wide",
                "Not going deep enough to stretch the long head",
                "Arching the lower back excessively"
            ]
        ),
        ExerciseGuide(
            name: "Skull Crusher",
            aliases: ["Lying Tricep Extension", "Skullcrusher", "Nose Breaker"],
            category: .triceps,
            description: "A tricep exercise lying on a bench, lowering the bar toward the forehead and pressing back up.",
            primaryMuscles: ["Triceps (all three heads)"],
            secondaryMuscles: ["Forearms"],
            formTips: [
                "Lie on a flat bench with arms extended, holding a bar or EZ bar",
                "Bend only at the elbows to lower the bar toward your forehead",
                "Keep your upper arms perpendicular to the floor",
                "Extend back up to full lockout, squeezing the triceps"
            ],
            commonMistakes: [
                "Moving the upper arms instead of only bending at the elbow",
                "Lowering the bar too far behind the head",
                "Flaring the elbows out wide during the movement"
            ]
        ),
        ExerciseGuide(
            name: "Close Grip Bench Press",
            aliases: ["CGBP", "Close Grip BP", "Narrow Grip Bench"],
            category: .triceps,
            description: "A bench press variation with a narrower grip that shifts emphasis from the chest to the triceps.",
            primaryMuscles: ["Triceps", "Pectoralis Major"],
            secondaryMuscles: ["Anterior Deltoid"],
            formTips: [
                "Grip the bar at shoulder width or slightly narrower",
                "Keep your elbows tucked close to your body",
                "Lower the bar to the lower chest",
                "Press up while focusing on tricep engagement"
            ],
            commonMistakes: [
                "Gripping too narrow, which stresses the wrists",
                "Flaring the elbows out, turning it into a regular bench press",
                "Not touching the chest at the bottom"
            ]
        ),
        ExerciseGuide(
            name: "Dips",
            aliases: ["Tricep Dips", "Parallel Bar Dips", "Weighted Dips"],
            category: .triceps,
            description: "A compound bodyweight exercise on parallel bars targeting the triceps, chest, and shoulders.",
            primaryMuscles: ["Triceps", "Pectoralis Major", "Anterior Deltoid"],
            secondaryMuscles: ["Core"],
            formTips: [
                "Grip the bars and lock out at the top with arms straight",
                "Lower by bending the elbows until your upper arms are parallel to the floor",
                "Keep your torso upright to emphasize triceps (lean forward for more chest)",
                "Press back up to full lockout"
            ],
            commonMistakes: [
                "Going too deep and straining the shoulders",
                "Swinging the legs for momentum",
                "Not achieving full lockout at the top"
            ]
        ),
        ExerciseGuide(
            name: "Diamond Push-Up",
            aliases: ["Close Grip Push-Up", "Triangle Push-Up"],
            category: .triceps,
            description: "A push-up variation with hands close together forming a diamond shape, heavily targeting the triceps.",
            primaryMuscles: ["Triceps", "Pectoralis Major"],
            secondaryMuscles: ["Anterior Deltoid", "Core"],
            formTips: [
                "Place your hands close together under your chest, forming a diamond with index fingers and thumbs",
                "Keep your body in a straight line from head to heels",
                "Lower your chest toward your hands",
                "Push up explosively, squeezing the triceps at the top"
            ],
            commonMistakes: [
                "Letting the hips sag or pike up",
                "Placing the hands too far forward",
                "Not going through full range of motion"
            ]
        ),

        // MARK: Legs

        ExerciseGuide(
            name: "Squat",
            aliases: ["Barbell Squat", "Back Squat", "BB Squat"],
            category: .legs,
            description: "The fundamental lower body compound exercise, squatting with a barbell on the upper back.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus"],
            secondaryMuscles: ["Hamstrings", "Erector Spinae", "Core", "Adductors"],
            formTips: [
                "Place the bar on your upper traps, grip the bar, and unrack",
                "Stand with feet shoulder-width apart, toes slightly pointed out",
                "Break at the hips and knees simultaneously, descend until thighs are at least parallel",
                "Drive through your whole foot to stand back up, keeping your chest up"
            ],
            commonMistakes: [
                "Caving the knees inward on the way up",
                "Rounding the lower back at the bottom of the squat",
                "Rising onto the toes and shifting weight forward",
                "Not squatting to adequate depth"
            ]
        ),
        ExerciseGuide(
            name: "Front Squat",
            aliases: ["Barbell Front Squat"],
            category: .legs,
            description: "A squat variation with the barbell held on the front of the shoulders, emphasizing the quads and demanding more core stability.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus"],
            secondaryMuscles: ["Core", "Upper Back", "Hamstrings"],
            formTips: [
                "Rest the bar on the front delts with a clean grip or cross-arm grip",
                "Keep your elbows high and chest up throughout the squat",
                "Descend while maintaining a more upright torso than a back squat",
                "Drive up through the whole foot, maintaining that high elbow position"
            ],
            commonMistakes: [
                "Letting the elbows drop, which causes the bar to roll forward",
                "Rounding the upper back under the weight",
                "Shifting forward onto the toes"
            ]
        ),
        ExerciseGuide(
            name: "Leg Press",
            aliases: ["45 Degree Leg Press", "Machine Leg Press"],
            category: .legs,
            description: "A machine compound exercise pushing weight away with the legs, allowing heavy loading with less spinal stress.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus"],
            secondaryMuscles: ["Hamstrings", "Adductors"],
            formTips: [
                "Position feet shoulder-width on the platform",
                "Lower the sled until your knees reach about 90 degrees",
                "Press through the whole foot without locking the knees at the top",
                "Higher foot placement emphasizes glutes, lower emphasizes quads"
            ],
            commonMistakes: [
                "Placing feet too low and letting the heels rise",
                "Lowering too far and rounding the lower back off the pad",
                "Fully locking out the knees at the top"
            ]
        ),
        ExerciseGuide(
            name: "Hack Squat",
            aliases: ["Hack Squat Machine"],
            category: .legs,
            description: "A machine squat variation that guides the movement path, heavily targeting the quadriceps.",
            primaryMuscles: ["Quadriceps"],
            secondaryMuscles: ["Gluteus Maximus", "Hamstrings"],
            formTips: [
                "Position your back flat against the pad with shoulders under the pads",
                "Place feet about shoulder width on the platform",
                "Lower until thighs are at least parallel to the platform",
                "Drive up through the heels and mid-foot"
            ],
            commonMistakes: [
                "Not going deep enough due to heavy loading",
                "Letting the knees cave inward",
                "Lifting the heels off the platform"
            ]
        ),
        ExerciseGuide(
            name: "Goblet Squat",
            aliases: ["DB Goblet Squat", "Dumbbell Goblet Squat", "Kettlebell Goblet Squat"],
            category: .legs,
            description: "A squat holding a dumbbell or kettlebell at the chest, excellent for learning squat mechanics.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus"],
            secondaryMuscles: ["Core", "Upper Back", "Adductors"],
            formTips: [
                "Hold the weight at your chest with both hands, elbows pointing down",
                "Squat down between your legs, using your elbows to push your knees out",
                "Keep your chest up and back straight throughout",
                "Great for warming up or learning proper squat depth"
            ],
            commonMistakes: [
                "Letting the weight pull you forward",
                "Not squatting deep enough",
                "Rounding the upper back"
            ]
        ),
        ExerciseGuide(
            name: "Bulgarian Split Squat",
            aliases: ["BSS", "Rear Foot Elevated Split Squat"],
            category: .legs,
            description: "A single-leg squat variation with the rear foot elevated on a bench, challenging balance and leg strength.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus"],
            secondaryMuscles: ["Hamstrings", "Adductors", "Core"],
            formTips: [
                "Place one foot behind you on a bench, laces down",
                "Step far enough forward so your front knee doesn't travel past your toes",
                "Lower until your rear knee nearly touches the floor",
                "Drive up through the front heel, keeping your torso upright"
            ],
            commonMistakes: [
                "Placing the front foot too close to the bench",
                "Leaning too far forward and loading the lower back",
                "Not going deep enough to engage the glutes"
            ]
        ),
        ExerciseGuide(
            name: "Leg Extension",
            aliases: ["Leg Extension Machine"],
            category: .legs,
            description: "A machine isolation exercise for the quadriceps, extending the knee against resistance.",
            primaryMuscles: ["Quadriceps"],
            secondaryMuscles: [],
            formTips: [
                "Adjust the pad so it sits on the front of your lower shins",
                "Extend your legs fully, squeezing the quads at the top",
                "Lower under control — don't let the weight drop",
                "Avoid hyperextending the knees at full extension"
            ],
            commonMistakes: [
                "Using momentum and swinging the weight",
                "Not controlling the eccentric phase",
                "Setting the pad too high or too low on the shin"
            ]
        ),
        ExerciseGuide(
            name: "Lunges",
            aliases: ["Walking Lunge", "Forward Lunge", "Dumbbell Lunge"],
            category: .legs,
            description: "A unilateral exercise stepping forward and lowering the rear knee toward the ground.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus"],
            secondaryMuscles: ["Hamstrings", "Core", "Adductors"],
            formTips: [
                "Take a large step forward and lower your rear knee toward the floor",
                "Keep your torso upright and front knee tracking over your toes",
                "Push off the front foot to return to the starting position",
                "Walking lunges are great for building endurance and coordination"
            ],
            commonMistakes: [
                "Taking too short a step, causing the front knee to go past the toes",
                "Leaning forward instead of staying upright",
                "Letting the knee cave inward on each step"
            ]
        ),
        ExerciseGuide(
            name: "Romanian Deadlift",
            aliases: ["RDL", "Stiff Leg Deadlift", "Dumbbell RDL", "DB RDL"],
            category: .legs,
            description: "A hip hinge movement that targets the hamstrings and glutes by lowering the bar with a slight knee bend.",
            primaryMuscles: ["Hamstrings", "Gluteus Maximus"],
            secondaryMuscles: ["Erector Spinae", "Core"],
            formTips: [
                "Hold the bar at hip height with a slight bend in the knees",
                "Hinge at the hips, pushing them back while keeping the bar close to your legs",
                "Lower until you feel a deep stretch in the hamstrings",
                "Drive your hips forward to return to standing, squeezing the glutes at the top"
            ],
            commonMistakes: [
                "Rounding the lower back instead of maintaining a neutral spine",
                "Bending the knees too much, turning it into a squat",
                "Letting the bar drift away from the body"
            ]
        ),
        ExerciseGuide(
            name: "Leg Curl",
            aliases: ["Lying Leg Curl", "Seated Leg Curl", "Hamstring Curl"],
            category: .legs,
            description: "A machine isolation exercise for the hamstrings, curling the lower legs against resistance.",
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Calves (gastrocnemius)"],
            formTips: [
                "Adjust the pad so it sits on the back of your lower legs above the ankles",
                "Curl your heels toward your glutes in a controlled motion",
                "Squeeze the hamstrings hard at the top of the movement",
                "Lower slowly — the eccentric phase is where the growth happens"
            ],
            commonMistakes: [
                "Lifting the hips off the pad to cheat (lying version)",
                "Using momentum instead of muscle control",
                "Not achieving a full contraction at the top"
            ]
        ),
        ExerciseGuide(
            name: "Nordic Curl",
            aliases: ["Nordic Hamstring Curl"],
            category: .legs,
            description: "An advanced bodyweight hamstring exercise lowering the body forward from a kneeling position.",
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Gluteus Maximus", "Core"],
            formTips: [
                "Kneel on a pad with your ankles secured under something solid",
                "Slowly lower your torso forward by straightening at the knees",
                "Resist gravity as long as possible with your hamstrings",
                "Catch yourself at the bottom and push back up, or use a band for assistance"
            ],
            commonMistakes: [
                "Bending at the hips instead of keeping a straight body line",
                "Dropping too fast without controlling the descent",
                "Not having the ankles properly secured"
            ]
        ),
        ExerciseGuide(
            name: "Deadlift",
            aliases: ["Conventional Deadlift", "Barbell Deadlift"],
            category: .legs,
            description: "The king of compound exercises — lifting a barbell from the floor to hip height, working nearly every muscle in the body.",
            primaryMuscles: ["Gluteus Maximus", "Hamstrings", "Erector Spinae", "Quadriceps"],
            secondaryMuscles: ["Trapezius", "Forearms", "Core", "Latissimus Dorsi"],
            formTips: [
                "Stand with feet hip-width apart, the bar over mid-foot",
                "Hinge down and grip the bar just outside your shins",
                "Brace your core, flatten your back, and drive through the floor",
                "Push the floor away with your legs first, then extend the hips to lockout"
            ],
            commonMistakes: [
                "Rounding the lower back — the most common and dangerous error",
                "Jerking the bar off the floor instead of building tension first",
                "Letting the bar drift forward away from the body",
                "Hyperextending the back at the top"
            ]
        ),
        ExerciseGuide(
            name: "Sumo Deadlift",
            aliases: ["Sumo DL"],
            category: .legs,
            description: "A deadlift variation with a wide stance and narrow grip, emphasizing the quads and adductors.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus", "Adductors"],
            secondaryMuscles: ["Hamstrings", "Erector Spinae", "Core"],
            formTips: [
                "Stand with a wide stance, toes pointed out at 30-45 degrees",
                "Grip the bar with a narrow grip inside your knees",
                "Push your knees out over your toes and drive through the floor",
                "Keep your chest up and hips close to the bar"
            ],
            commonMistakes: [
                "Letting the knees cave inward during the pull",
                "Shooting the hips up first, rounding the back",
                "Not pushing the knees out enough at the start"
            ]
        ),
        ExerciseGuide(
            name: "Trap Bar Deadlift",
            aliases: ["Hex Bar Deadlift"],
            category: .legs,
            description: "A deadlift using a trap (hex) bar which shifts the center of gravity and is easier on the lower back.",
            primaryMuscles: ["Quadriceps", "Gluteus Maximus", "Hamstrings"],
            secondaryMuscles: ["Erector Spinae", "Trapezius", "Core"],
            formTips: [
                "Stand inside the trap bar with feet hip-width apart",
                "Hinge down and grip the handles at your sides",
                "Drive through the floor, keeping your torso upright",
                "The neutral grip and center of gravity make this easier to learn than conventional"
            ],
            commonMistakes: [
                "Treating it like a squat and bending the knees too much",
                "Rounding the lower back despite the easier position",
                "Not standing fully upright at the top"
            ]
        ),
        ExerciseGuide(
            name: "Hip Thrust",
            aliases: ["Barbell Hip Thrust", "Glute Bridge", "Weighted Glute Bridge"],
            category: .legs,
            description: "A glute-dominant exercise driving the hips up against a barbell while the upper back is supported on a bench.",
            primaryMuscles: ["Gluteus Maximus"],
            secondaryMuscles: ["Hamstrings", "Core", "Quadriceps"],
            formTips: [
                "Sit on the floor with your upper back against a bench, bar over your hips",
                "Plant your feet about shoulder-width apart, shins vertical at the top",
                "Drive your hips up until your torso is parallel to the floor",
                "Squeeze the glutes hard at the top and hold briefly"
            ],
            commonMistakes: [
                "Hyperextending the lower back at the top instead of using the glutes",
                "Placing feet too far forward or too close",
                "Not achieving full hip extension"
            ]
        ),
        ExerciseGuide(
            name: "Calf Raise",
            aliases: ["Standing Calf Raise", "Seated Calf Raise", "Machine Calf Raise"],
            category: .legs,
            description: "An isolation exercise raising up onto the toes to target the calf muscles.",
            primaryMuscles: ["Gastrocnemius", "Soleus"],
            secondaryMuscles: [],
            formTips: [
                "Stand on the edge of a step or platform with heels hanging off",
                "Rise up as high as possible onto your toes",
                "Hold the top position and squeeze the calves",
                "Lower slowly below the platform level for a full stretch"
            ],
            commonMistakes: [
                "Bouncing at the bottom without controlling the stretch",
                "Not going through full range of motion",
                "Bending the knees and turning it into a squat motion"
            ]
        ),
        ExerciseGuide(
            name: "Good Morning",
            aliases: ["Barbell Good Morning"],
            category: .legs,
            description: "A hip hinge exercise with a bar on the back, targeting the hamstrings and lower back.",
            primaryMuscles: ["Hamstrings", "Erector Spinae"],
            secondaryMuscles: ["Gluteus Maximus", "Core"],
            formTips: [
                "Place the bar on your upper back as you would for a squat",
                "Keep a slight bend in the knees and hinge at the hips",
                "Lower your torso until it is roughly parallel to the floor",
                "Drive the hips forward to return to standing"
            ],
            commonMistakes: [
                "Rounding the lower back during the movement",
                "Using too much weight before mastering the form",
                "Bending the knees too much, turning it into a squat"
            ]
        ),

        // MARK: Core

        ExerciseGuide(
            name: "Plank",
            aliases: ["Front Plank", "Forearm Plank"],
            category: .core,
            description: "An isometric core exercise holding a push-up position on the forearms to build core stability.",
            primaryMuscles: ["Rectus Abdominis", "Transverse Abdominis"],
            secondaryMuscles: ["Obliques", "Erector Spinae", "Shoulders"],
            formTips: [
                "Rest on your forearms with elbows directly under your shoulders",
                "Keep your body in a perfectly straight line from head to heels",
                "Brace your core as if bracing for a punch",
                "Focus on breathing steadily while maintaining tension"
            ],
            commonMistakes: [
                "Letting the hips sag toward the floor",
                "Piking the hips up too high",
                "Holding your breath instead of breathing normally"
            ]
        ),
        ExerciseGuide(
            name: "Cable Crunch",
            aliases: ["Kneeling Cable Crunch"],
            category: .core,
            description: "A weighted ab exercise kneeling in front of a cable, crunching down against resistance.",
            primaryMuscles: ["Rectus Abdominis"],
            secondaryMuscles: ["Obliques"],
            formTips: [
                "Kneel facing the cable with the rope behind your head",
                "Crunch down by flexing the spine, bringing your elbows toward your knees",
                "Focus on curling the torso, not just hinging at the hips",
                "Return slowly to the starting position and maintain tension"
            ],
            commonMistakes: [
                "Sitting back onto the heels instead of crunching the spine",
                "Using the arms to pull the rope down instead of the abs",
                "Moving at the hips instead of flexing the spine"
            ]
        ),
        ExerciseGuide(
            name: "Hanging Leg Raise",
            aliases: ["Hanging Knee Raise", "Leg Raise"],
            category: .core,
            description: "An advanced ab exercise hanging from a bar and raising the legs to work the lower abs and hip flexors.",
            primaryMuscles: ["Rectus Abdominis (lower)", "Hip Flexors"],
            secondaryMuscles: ["Obliques", "Forearms (grip)"],
            formTips: [
                "Hang from a bar with arms straight and shoulders engaged",
                "Raise your legs by curling your pelvis upward, not just swinging",
                "For beginners: raise knees to chest. Advanced: straight legs to horizontal",
                "Lower under control without swinging"
            ],
            commonMistakes: [
                "Swinging and using momentum instead of muscle control",
                "Only raising the legs without curling the pelvis",
                "Losing grip before the abs are fatigued"
            ]
        ),
        ExerciseGuide(
            name: "Ab Wheel Rollout",
            aliases: ["Ab Roller", "Ab Wheel"],
            category: .core,
            description: "A challenging core exercise rolling an ab wheel forward and pulling it back using core strength.",
            primaryMuscles: ["Rectus Abdominis", "Transverse Abdominis"],
            secondaryMuscles: ["Latissimus Dorsi", "Shoulders", "Hip Flexors"],
            formTips: [
                "Start on your knees holding the ab wheel beneath your shoulders",
                "Roll forward slowly, extending your body as far as you can control",
                "Keep your core tight and don't let your hips sag",
                "Pull the wheel back using your abs, not your arms"
            ],
            commonMistakes: [
                "Going too far forward and collapsing",
                "Letting the lower back arch excessively",
                "Using the arms and shoulders instead of the core"
            ]
        ),
        ExerciseGuide(
            name: "Russian Twist",
            aliases: ["Weighted Russian Twist"],
            category: .core,
            description: "A rotational core exercise sitting with the torso angled back, twisting side to side.",
            primaryMuscles: ["Obliques"],
            secondaryMuscles: ["Rectus Abdominis", "Hip Flexors"],
            formTips: [
                "Sit with knees bent, lean back to about 45 degrees",
                "Hold a weight at your chest and rotate your torso side to side",
                "Keep your feet on the floor (or lifted for more challenge)",
                "Move deliberately — this is about rotation, not speed"
            ],
            commonMistakes: [
                "Only moving the arms instead of rotating the whole torso",
                "Going too fast and losing control",
                "Rounding the back instead of maintaining a proud chest"
            ]
        ),
        ExerciseGuide(
            name: "Dead Bug",
            aliases: [],
            category: .core,
            description: "An anti-extension core exercise lying on your back, extending opposite arm and leg while maintaining a flat back.",
            primaryMuscles: ["Transverse Abdominis", "Rectus Abdominis"],
            secondaryMuscles: ["Hip Flexors", "Erector Spinae"],
            formTips: [
                "Lie on your back with arms extended toward the ceiling and knees at 90 degrees",
                "Press your lower back firmly into the floor",
                "Slowly extend one arm overhead while extending the opposite leg",
                "Return to start and repeat on the other side"
            ],
            commonMistakes: [
                "Letting the lower back arch off the floor",
                "Moving too fast and losing core engagement",
                "Not fully extending the arm and leg"
            ]
        ),
        ExerciseGuide(
            name: "Pallof Press",
            aliases: ["Anti-Rotation Press"],
            category: .core,
            description: "An anti-rotation exercise pressing a cable away from the chest while resisting the pull to rotate.",
            primaryMuscles: ["Obliques", "Transverse Abdominis"],
            secondaryMuscles: ["Rectus Abdominis", "Shoulders"],
            formTips: [
                "Stand sideways to a cable machine with the handle at chest height",
                "Hold the handle at your chest, then press it straight out in front of you",
                "Resist the cable's pull to rotate — this is the core work",
                "Hold the extended position for 2-3 seconds, then return to chest"
            ],
            commonMistakes: [
                "Letting the cable rotate your torso",
                "Standing too close to the machine, reducing the challenge",
                "Rushing through the reps instead of holding the extended position"
            ]
        ),
        ExerciseGuide(
            name: "Decline Sit-Up",
            aliases: ["Decline Crunch", "Weighted Sit-Up"],
            category: .core,
            description: "A sit-up performed on a decline bench for increased resistance on the abdominals.",
            primaryMuscles: ["Rectus Abdominis"],
            secondaryMuscles: ["Hip Flexors", "Obliques"],
            formTips: [
                "Secure your feet at the top of the decline bench",
                "Cross your arms over your chest or hold a weight plate",
                "Curl your torso up by flexing the spine, not hinging at the hips",
                "Lower back slowly under control"
            ],
            commonMistakes: [
                "Using momentum to swing up",
                "Pulling on the neck with your hands",
                "Setting the decline too steep before building strength"
            ]
        ),

        // MARK: Cardio

        ExerciseGuide(
            name: "Running",
            aliases: ["Treadmill", "Jogging", "Treadmill Run"],
            category: .cardio,
            description: "Cardiovascular exercise moving at a pace faster than walking, either outdoors or on a treadmill.",
            primaryMuscles: ["Quadriceps", "Hamstrings", "Calves", "Gluteus Maximus"],
            secondaryMuscles: ["Core", "Hip Flexors"],
            formTips: [
                "Land with a midfoot strike under your center of gravity",
                "Keep a slight forward lean from the ankles, not the waist",
                "Maintain a cadence of 160-180 steps per minute",
                "Relax your shoulders and keep arms swinging at roughly 90 degrees"
            ],
            commonMistakes: [
                "Overstriding and heel-striking ahead of the body",
                "Tensing the shoulders up toward the ears",
                "Starting too fast and burning out early"
            ]
        ),
        ExerciseGuide(
            name: "Rowing",
            aliases: ["Rowing Machine", "Erg", "Concept 2", "Indoor Rowing"],
            category: .cardio,
            description: "A full-body cardiovascular exercise on an ergometer, mimicking the rowing motion.",
            primaryMuscles: ["Latissimus Dorsi", "Quadriceps", "Hamstrings"],
            secondaryMuscles: ["Biceps", "Core", "Calves", "Shoulders"],
            formTips: [
                "Start with arms extended and shins vertical (the catch position)",
                "Drive with the legs first, then lean back slightly, then pull the handle to your chest",
                "Reverse the sequence on the recovery: arms, body, then legs",
                "Maintain a strong posture — don't round your back"
            ],
            commonMistakes: [
                "Pulling with the arms before the legs have finished driving",
                "Rounding the back during the drive phase",
                "Rushing the recovery and not letting the flywheel spin"
            ]
        ),
        ExerciseGuide(
            name: "Cycling",
            aliases: ["Bike", "Stationary Bike", "Spin Bike", "Indoor Cycling"],
            category: .cardio,
            description: "A low-impact cardiovascular exercise pedaling a bicycle or stationary bike.",
            primaryMuscles: ["Quadriceps", "Hamstrings", "Gluteus Maximus"],
            secondaryMuscles: ["Calves", "Core"],
            formTips: [
                "Set the seat height so your knee has a slight bend at the bottom of the pedal stroke",
                "Keep your upper body relaxed and avoid gripping the handlebars too tight",
                "Maintain a smooth, circular pedaling motion",
                "Aim for a cadence of 60-100 RPM depending on resistance"
            ],
            commonMistakes: [
                "Setting the seat too low, causing knee pain",
                "Bouncing in the saddle at high cadence",
                "Gripping the handlebars too tight and tensing the upper body"
            ]
        ),
        ExerciseGuide(
            name: "Jump Rope",
            aliases: ["Skipping Rope", "Skipping"],
            category: .cardio,
            description: "A high-intensity cardiovascular exercise jumping over a swinging rope to build coordination and endurance.",
            primaryMuscles: ["Calves", "Quadriceps"],
            secondaryMuscles: ["Shoulders", "Core", "Forearms"],
            formTips: [
                "Keep your elbows close to your sides, rotating only from the wrists",
                "Jump just high enough to clear the rope — about 1-2 inches",
                "Stay on the balls of your feet with soft knees",
                "Keep your gaze forward and maintain a steady rhythm"
            ],
            commonMistakes: [
                "Jumping too high and wasting energy",
                "Using the whole arm to swing the rope instead of the wrists",
                "Landing flat-footed, which is hard on the joints"
            ]
        ),
    ]
}
