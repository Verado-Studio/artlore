import '../models/painting.dart';

/// Static sample data standing in for the AI identification pipeline.
class MockPaintings {
  MockPaintings._();

  static const Painting starryNight = Painting(
    title: 'The Starry Night',
    artist: 'Vincent van Gogh',
    year: '1889',
    movement: 'Post-Impressionism',
    museum: 'Museum of Modern Art, New York',
    confidence: 96,
    imageSeed: 0,
    hook: "He painted this from memory, in an asylum, the night before dawn broke his fever.",
    stories: {
      'Kid':
          "Vincent looked out of his window at night and saw the stars swirling like they were dancing! "
              "He was feeling a little sad, so he painted the sky the way it felt in his heart — big, "
              "bright, and a little bit magical.",
      'Simple':
          "Van Gogh painted The Starry Night in 1889 while staying at an asylum in France. It shows "
              "the view from his window, but the swirling sky came from his imagination rather than "
              "what he actually saw. It's now one of the most recognised paintings in the world.",
      'Art-lover':
          "Painted during Van Gogh's stay at the Saint-Paul-de-Mausole asylum, this work departs from "
              "plein air observation entirely — the cypress, village, and sky are reassembled from memory "
              "and imagination. The rhythmic, impasto brushwork and turbulent sky have been read as a "
              "visual analogue for his emotional state, though Van Gogh himself described the painting "
              "with characteristic restraint in his letters to Theo.",
    },
    details: [
      PaintingDetail(
        x: 0.28,
        y: 0.32,
        title: 'The swirling sky',
        description:
            'The turbulent cloud formation was likely influenced by both his emotional state and '
            'contemporary astronomical illustrations he had seen in magazines.',
      ),
      PaintingDetail(
        x: 0.14,
        y: 0.68,
        title: 'The cypress tree',
        description:
            'Cypress trees were traditionally associated with mourning and cemeteries in Europe, '
            'linking the foreground to themes of mortality.',
      ),
      PaintingDetail(
        x: 0.78,
        y: 0.22,
        title: 'The crescent moon',
        description:
            'Van Gogh painted the moon as a glowing crescent rather than the full moon that was '
            'actually visible that night — an intentional artistic choice.',
      ),
    ],
  );

  static const Painting girlWithPearl = Painting(
    title: 'Girl with a Pearl Earring',
    artist: 'Johannes Vermeer',
    year: 'c. 1665',
    movement: 'Dutch Golden Age',
    museum: 'Mauritshuis, The Hague',
    confidence: 91,
    imageSeed: 1,
    hook: "Nobody knows her name. Three centuries later, she still won't stop looking at you.",
    stories: {
      'Kid':
          "This girl is wearing a big shiny pearl earring and a cool blue and yellow scarf. The "
          "painter made her look over her shoulder right at us, like she's about to say something!",
      'Simple':
          "Painted by Johannes Vermeer around 1665, this isn't a portrait of a real person with a "
          "name — it's what's called a 'tronie', a study of an imagined face. The pearl and the "
          "turban-like headscarf make it feel exotic and mysterious.",
      'Art-lover':
          "Often dubbed the 'Mona Lisa of the North', this tronie exemplifies Vermeer's mastery of "
          "light. The famous pearl earring is rendered with just two brushstrokes of white — no "
          "actual pearl of that size existed at the time, suggesting artistic license. The subject's "
          "ambiguous expression and directness of gaze continue to fuel scholarly debate.",
    },
    details: [
      PaintingDetail(
        x: 0.58,
        y: 0.55,
        title: 'The pearl',
        description:
            "Rendered with only a couple of confident highlights, the earring is disproportionately "
            "large for a real pearl — likely painted for symbolic shine rather than accuracy.",
      ),
      PaintingDetail(
        x: 0.45,
        y: 0.2,
        title: 'The turban',
        description:
            'The blue and yellow headwrap reflects the 17th-century Dutch fascination with exotic, '
            'imported textiles from the East.',
        locked: true,
      ),
      PaintingDetail(
        x: 0.5,
        y: 0.42,
        title: 'The parted lips',
        description:
            'Unusual for portraiture of the era, her slightly open mouth gives the sense of a '
            'captured, fleeting moment rather than a formal pose.',
        locked: true,
      ),
    ],
  );

  static const Painting unknownStillLife = Painting(
    title: 'Untitled Still Life',
    artist: 'Unknown',
    year: 'Unknown',
    movement: 'Likely Dutch Baroque',
    museum: '—',
    confidence: 42,
    imageSeed: 2,
    hook: "We couldn't pin this one down — but its brushwork tells its own story.",
    stories: {
      'Kid':
          "We're not totally sure who painted this one, but look at all those fruits and flowers! "
          "The painter was really good at making them look real enough to touch.",
      'Simple':
          "This piece couldn't be matched to a known work with confidence, but its heavy shadows, "
          "rich fruit, and glossy highlights point to the Dutch Baroque still-life tradition.",
      'Art-lover':
          "Stylistic markers — tenebrous background, glazed highlights on glassware, and a diagonal "
          "compositional sweep — suggest a workshop piece from the Dutch Baroque still-life tradition, "
          "though no confident attribution can be made.",
    },
    details: [],
  );

  static const List<Painting> collection = [starryNight, girlWithPearl, unknownStillLife];
}
