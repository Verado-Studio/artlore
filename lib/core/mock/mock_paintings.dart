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

  static const Painting monaLisa = Painting(
    title: 'Mona Lisa',
    artist: 'Leonardo da Vinci',
    year: 'c. 1503–1506',
    movement: 'High Renaissance',
    museum: 'Louvre Museum, Paris',
    confidence: 98,
    imageSeed: 3,
    hook: "The most famous smile in art history — and nobody agrees on what it means.",
    stories: {
      'Kid':
          "This lady's smile is a bit of a mystery! Some days it looks happy, some days it looks a "
          "little sad. Leonardo painted her so cleverly that her face seems to change depending on "
          "how you look at it.",
      'Simple':
          "Leonardo da Vinci painted the Mona Lisa in the early 1500s. It's famous for her mysterious "
          "half-smile and for the hazy, soft-edged technique Leonardo used to paint it, called sfumato. "
          "It's one of the most visited paintings in the world.",
      'Art-lover':
          "Leonardo's sfumato technique — blending tones and edges without harsh outlines — gives the "
          "sitter's expression its famous ambiguity, shifting with the viewer's angle and focus. Likely "
          "a portrait of Lisa Gherardini, the painting stayed in Leonardo's own possession until his "
          "death, unusually personal for a commissioned portrait of the era.",
    },
    details: [
      PaintingDetail(
        x: 0.5,
        y: 0.38,
        title: 'The smile',
        description:
            'Painted with soft, blended transitions rather than hard lines, the sfumato technique '
            'makes her expression seem to shift depending on where you look.',
      ),
      PaintingDetail(
        x: 0.5,
        y: 0.72,
        title: 'The hands',
        description:
            'Her calmly folded hands were considered a striking innovation in portraiture, giving the '
            'sitter a relaxed, dignified informality rare for the period.',
        locked: true,
      ),
      PaintingDetail(
        x: 0.75,
        y: 0.25,
        title: 'The landscape',
        description:
            'The hazy, imaginary landscape behind her recedes into blue-toned aerial perspective, a '
            'technique Leonardo helped pioneer.',
        locked: true,
      ),
    ],
  );

  static const Painting prodigalSon = Painting(
    title: 'The Return of the Prodigal Son',
    artist: 'Rembrandt van Rijn',
    year: 'c. 1668',
    movement: 'Dutch Golden Age',
    museum: 'The Hermitage Museum, Saint Petersburg',
    confidence: 90,
    imageSeed: 4,
    hook: "Painted in the last year of his life, it's Rembrandt's quiet meditation on forgiveness.",
    stories: {
      'Kid':
          "A ragged, tired son kneels down and his father wraps him in a big, gentle hug. The father "
          "is so happy his son came home that nothing else matters anymore.",
      'Simple':
          "Rembrandt painted this near the end of his life, around 1668. It shows the Bible story of "
          "the prodigal son returning home in rags after wasting his inheritance, and being forgiven "
          "and embraced by his father without a single word of blame.",
      'Art-lover':
          "One of Rembrandt's final works, painted with the loose, almost sculptural brushwork of his "
          "late period. The warm reds enveloping father and son draw the eye straight to the embrace, "
          "while the onlookers recede into shadow — Rembrandt strips the scene down to pure, wordless "
          "mercy.",
    },
    details: [
      PaintingDetail(
        x: 0.35,
        y: 0.55,
        title: 'The embrace',
        description:
            "The father's two hands are painted differently — one broad and masculine, one softer — "
            "often read as blending paternal and maternal tenderness in a single gesture.",
      ),
      PaintingDetail(
        x: 0.35,
        y: 0.82,
        title: 'The worn sandal',
        description:
            "The son's tattered clothes and one bare, calloused foot show the poverty and hardship of "
            "his journey home.",
        locked: true,
      ),
      PaintingDetail(
        x: 0.72,
        y: 0.4,
        title: 'The watching figure',
        description:
            'The elder son stands apart in the shadows, widely interpreted as struggling with '
            'resentment at his brother\'s welcome.',
        locked: true,
      ),
    ],
  );

  static const Painting nightWatch = Painting(
    title: 'The Night Watch',
    artist: 'Rembrandt van Rijn',
    year: '1642',
    movement: 'Dutch Golden Age',
    museum: 'Rijksmuseum, Amsterdam',
    confidence: 94,
    imageSeed: 5,
    hook: "It isn't actually set at night — centuries of dirty varnish just made everyone think so.",
    stories: {
      'Kid':
          "This huge painting shows a group of soldiers marching out, all bustling and busy. For a "
          "long time people thought it showed nighttime because it looked so dark — but that was just "
          "old, dirty varnish!",
      'Simple':
          "Rembrandt painted this militia group portrait in 1642. Its real title is much longer, and "
          "it wasn't originally a night scene at all — grime and darkened varnish over the centuries "
          "made it look that way until it was cleaned.",
      'Art-lover':
          "Rembrandt broke from the static, row-by-row convention of Dutch militia portraits, staging "
          "the company mid-movement with dramatic chiaroscuro lighting picking key figures out of the "
          "crowd. The painting was trimmed on all sides in 1715 to fit a new location, permanently "
          "altering its original composition.",
    },
    details: [
      PaintingDetail(
        x: 0.42,
        y: 0.45,
        title: 'Captain Cocq',
        description:
            'The dark-clad figure in the center commissioned the piece along with his militia company '
            '— unusually, Rembrandt shows him mid-gesture rather than posed still.',
      ),
      PaintingDetail(
        x: 0.58,
        y: 0.55,
        title: 'The mysterious girl',
        description:
            'A small girl in golden light glows amid the soldiers for no clear narrative reason — one '
            'of the painting\'s most debated details.',
        locked: true,
      ),
      PaintingDetail(
        x: 0.2,
        y: 0.35,
        title: 'The lighting',
        description:
            "Rembrandt's dramatic light-and-shadow staging was radical for a group portrait, breaking "
            "from the flat, evenly lit convention of the genre.",
        locked: true,
      ),
    ],
  );

  static const List<Painting> collection = [starryNight, girlWithPearl, unknownStillLife];
}
