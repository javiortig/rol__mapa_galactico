-- Necron prices from the official MFM, refreshed on 2026-10-15.
-- Existing resources, completed recruitment history and destroyed units are untouched.
do $$
declare
  -- BEGIN GENERATED NECRONS MFM PAYLOAD
  v_items jsonb := $mfm$[{"slug":"unit-necrones-ctan-shard-of-the-deceiver","points":330,"costs":{"supply":53,"minerals":16,"honor":33,"gold":16},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":330,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-ctan-shard-of-the-nightbringer","points":360,"costs":{"supply":54,"minerals":18,"honor":36,"gold":18},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":360,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-ctan-shard-of-the-void-dragon","points":345,"costs":{"supply":56,"minerals":17,"honor":34,"gold":17},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":345,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-catacomb-command-barge","points":120,"costs":{"supply":30,"minerals":15,"honor":12,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":120,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-chronomancer","points":70,"costs":{"supply":25,"minerals":5,"honor":7,"gold":0},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":70,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-geomancer","points":75,"costs":{"supply":22,"minerals":9,"honor":7,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-hexmark-destroyer","points":75,"costs":{"supply":22,"minerals":9,"honor":7,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-illuminor-szeras","points":175,"costs":{"supply":48,"minerals":21,"honor":17,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":175,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-imotekh-the-stormlord","points":100,"costs":{"supply":26,"minerals":12,"honor":10,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":100,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-lokhust-lord","points":80,"costs":{"supply":20,"minerals":10,"honor":8,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-nekrosor-ammentar","points":195,"costs":{"supply":52,"minerals":24,"honor":19,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":195,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-orikan-the-diviner","points":90,"costs":{"supply":23,"minerals":11,"honor":9,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-overlord","points":90,"costs":{"supply":23,"minerals":11,"honor":9,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-overlord-with-translocation-shroud","points":90,"costs":{"supply":23,"minerals":11,"honor":9,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-plasmancer","points":60,"costs":{"supply":22,"minerals":4,"honor":6,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-psychomancer","points":65,"costs":{"supply":27,"minerals":4,"honor":6,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":65,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-royal-warden","points":50,"costs":{"supply":19,"minerals":3,"honor":5,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":50,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-skorpekh-lord","points":95,"costs":{"supply":28,"minerals":11,"honor":9,"gold":0},"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":95,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":105,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-technomancer","points":80,"costs":{"supply":20,"minerals":10,"honor":8,"gold":0},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-the-silent-king","points":420,"costs":{"supply":63,"minerals":21,"honor":42,"gold":21},"models":[{"slug":"models-3-3-copy-1-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":420,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-transcendent-ctan","points":340,"costs":{"supply":51,"minerals":17,"honor":34,"gold":17},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":340,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":360,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-trazyn-the-infinite","points":60,"costs":{"supply":22,"minerals":4,"honor":6,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-immortals","points":65,"costs":{"supply":65,"minerals":0,"honor":0,"gold":0},"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":65,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":130,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-necron-warriors","points":85,"costs":{"supply":85,"minerals":0,"honor":0,"gold":0},"models":[{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-20-20-copy-1-plus","label":"20 models","models":20,"minModels":20,"maxModels":20,"points":190,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-annihilation-barge","points":100,"costs":{"supply":0,"minerals":50,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":100,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-doomstalker","points":130,"costs":{"supply":0,"minerals":65,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":130,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-macrocytes","points":70,"costs":{"supply":36,"minerals":17,"honor":0,"gold":0},"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":70,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-reanimator","points":75,"costs":{"supply":0,"minerals":38,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-scarab-swarms","points":40,"costs":{"supply":28,"minerals":6,"honor":0,"gold":0},"models":[{"slug":"models-3-3-copy-1-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":40,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-1-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-spyders","points":65,"costs":{"supply":0,"minerals":33,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":65,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-2-2-copy-1-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":110,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-tomb-crawlers","points":60,"costs":{"supply":42,"minerals":9,"honor":0,"gold":0},"models":[{"slug":"models-2-2-copy-1-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-canoptek-wraiths","points":95,"costs":{"supply":41,"minerals":17,"honor":0,"gold":4},"models":[{"slug":"models-3-3-copy-1-1","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":95,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-1-1","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":220,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-2-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":115,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-2-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":240,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-convergence-of-dominion","points":60,"costs":{"supply":0,"minerals":30,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-2-2-copy-1-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":120,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-1-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":180,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-cryptothralls","points":60,"costs":{"supply":42,"minerals":9,"honor":0,"gold":0},"models":[{"slug":"models-2-2-copy-1-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-deathmarks","points":60,"costs":{"supply":42,"minerals":9,"honor":0,"gold":0},"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":60,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":120,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":70,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":130,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-doom-scythe","points":200,"costs":{"supply":0,"minerals":100,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":200,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-doomsday-ark","points":200,"costs":{"supply":0,"minerals":100,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":200,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":230,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-flayed-ones","points":55,"costs":{"supply":55,"minerals":0,"honor":0,"gold":0},"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":55,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":100,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-ghost-ark","points":100,"costs":{"supply":0,"minerals":50,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":100,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-lokhust-destroyers","points":40,"costs":{"supply":28,"minerals":6,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":40,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-2-2-copy-1-2","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":55,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":80,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-1-2","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":190,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":70,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-2-2-copy-3-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":85,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":110,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-3-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":220,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-lokhust-heavy-destroyers","points":50,"costs":{"supply":36,"minerals":7,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":50,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-2-2-copy-1-2","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":100,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":165,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-2-2-copy-3-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":110,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":175,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-lychguard","points":80,"costs":{"supply":40,"minerals":20,"honor":0,"gold":0},"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":160,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-monolith","points":420,"costs":{"supply":0,"minerals":158,"honor":0,"gold":21},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":420,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":440,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-night-scythe","points":125,"costs":{"supply":0,"minerals":63,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":125,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-obelisk","points":280,"costs":{"supply":0,"minerals":105,"honor":0,"gold":14},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":280,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":310,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-ophydian-destroyers","points":80,"costs":{"supply":30,"minerals":15,"honor":0,"gold":4},"models":[{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":80,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-1-2","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":150,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":90,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-3-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":160,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-seraptek-heavy-construct","points":540,"costs":{"supply":0,"minerals":203,"honor":0,"gold":27},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":540,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":570,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-skorpekh-destroyers","points":85,"costs":{"supply":35,"minerals":15,"honor":0,"gold":4},"models":[{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":85,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-1-2","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":170,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":95,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-3-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":180,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-tesseract-vault","points":465,"costs":{"supply":0,"minerals":175,"honor":0,"gold":23},"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":465,"copyFrom":1,"copyTo":1,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":505,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-tomb-blades","points":70,"costs":{"supply":29,"minerals":13,"honor":0,"gold":3},"models":[{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":70,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-1-2","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":140,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":80,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-6-6-copy-3-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":150,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-triarch-praetorians","points":80,"costs":{"supply":40,"minerals":20,"honor":0,"gold":0},"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":160,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-necrones-triarch-stalker","points":110,"costs":{"supply":0,"minerals":55,"honor":0,"gold":0},"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":110,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":120,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]}]$mfm$::jsonb;
  -- END GENERATED NECRONS MFM PAYLOAD
  v_item jsonb;
  v_option jsonb;
  v_template public.unit_templates%rowtype;
  v_model_option public.unit_template_model_options%rowtype;
  v_unit public.campaign_units%rowtype;
  v_queue public.recruitment_queue%rowtype;
  v_wargear_options jsonb;
  v_wargear_points integer;
begin
  for v_item in select value from jsonb_array_elements(v_items) loop
    select * into v_template
    from public.unit_templates
    where slug = v_item->>'slug'
      and faction_id = (select id from public.factions where slug = 'necrones')
    for update;

    if not found then
      continue;
    end if;

    update public.unit_templates
    set points = (v_item->>'points')::integer,
        supply_cost = (v_item->'costs'->>'supply')::integer,
        minerals_cost = (v_item->'costs'->>'minerals')::integer,
        honor_cost = (v_item->'costs'->>'honor')::integer,
        gold_cost = (v_item->'costs'->>'gold')::integer
    where id = v_template.id;

    for v_option in select value from jsonb_array_elements(v_item->'models') loop
      insert into public.unit_template_model_options (
        id, unit_template_id, slug, label, models, min_models, max_models,
        points, copy_from, copy_to, source, points_change_direction, points_change_amount
      ) values (
        public.seed_uuid('unit_template_model_option', (v_item->>'slug') || ':' || (v_option->>'slug')),
        v_template.id, v_option->>'slug', v_option->>'label',
        (v_option->>'models')::integer, (v_option->>'minModels')::integer,
        (v_option->>'maxModels')::integer, (v_option->>'points')::integer,
        (v_option->>'copyFrom')::integer, (v_option->>'copyTo')::integer,
        'mfm', v_option->>'changeDirection', (v_option->>'changeAmount')::integer
      )
      on conflict (unit_template_id, slug) do update
      set label = excluded.label, models = excluded.models,
          min_models = excluded.min_models, max_models = excluded.max_models,
          points = excluded.points, copy_from = excluded.copy_from,
          copy_to = excluded.copy_to, source = excluded.source,
          points_change_direction = excluded.points_change_direction,
          points_change_amount = excluded.points_change_amount, updated_at = now();
    end loop;

    for v_option in select value from jsonb_array_elements(v_item->'wargear') loop
      insert into public.unit_template_wargear_options (
        id, unit_template_id, slug, name, points, pricing, source,
        points_change_direction, points_change_amount
      ) values (
        public.seed_uuid('unit_template_wargear_option', (v_item->>'slug') || ':' || (v_option->>'slug')),
        v_template.id, v_option->>'slug', v_option->>'name',
        (v_option->>'points')::integer, v_option->>'pricing', 'mfm',
        v_option->>'changeDirection', (v_option->>'changeAmount')::integer
      )
      on conflict (unit_template_id, slug) do update
      set name = excluded.name, points = excluded.points, pricing = excluded.pricing,
          source = excluded.source,
          points_change_direction = excluded.points_change_direction,
          points_change_amount = excluded.points_change_amount, updated_at = now();
    end loop;

    -- Old options must not remain recruitable after the official list changes.
    delete from public.unit_template_model_options as model_option
    where model_option.unit_template_id = v_template.id
      and not exists (
        select 1 from jsonb_array_elements(v_item->'models') as listed(value)
        where listed.value->>'slug' = model_option.slug
      );

    delete from public.unit_template_wargear_options as wargear_option
    where wargear_option.unit_template_id = v_template.id
      and not exists (
        select 1 from jsonb_array_elements(v_item->'wargear') as listed(value)
        where listed.value->>'slug' = wargear_option.slug
      );

    for v_unit in
      select * from public.campaign_units
      where unit_template_id = v_template.id and status <> 'destroyed' and quantity > 0
      for update
    loop
      select * into v_model_option
      from public.unit_template_model_options
      where unit_template_id = v_template.id
        and min_models <= v_unit.starting_quantity
        and max_models >= v_unit.starting_quantity
        and copy_from = 1
      order by max_models, min_models desc
      limit 1;

      if not found then
        raise exception 'MFM has no first-copy price for % (% models)', v_unit.name, v_unit.starting_quantity;
      end if;

      select coalesce(jsonb_agg(
        selected.value || jsonb_build_object(
          'points', coalesce(wargear.points, (selected.value->>'points')::integer, 0),
          'totalPoints', coalesce(wargear.points, (selected.value->>'points')::integer, 0)
            * coalesce((selected.value->>'quantity')::integer, 1)
        )
      ), '[]'::jsonb)
      into v_wargear_options
      from jsonb_array_elements(coalesce(v_unit.selected_wargear_options, '[]'::jsonb)) as selected(value)
      left join public.unit_template_wargear_options as wargear
        on wargear.unit_template_id = v_template.id and wargear.slug = selected.value->>'slug';

      select coalesce(sum((selected.value->>'totalPoints')::integer), 0)
      into v_wargear_points
      from jsonb_array_elements(v_wargear_options) as selected(value);

      update public.campaign_units
      set points = v_model_option.points + v_wargear_points,
          selected_model_option_id = v_model_option.id,
          selected_wargear_points = v_wargear_points,
          selected_wargear_options = v_wargear_options,
          point_cost_breakdown = coalesce(point_cost_breakdown, '{}'::jsonb) ||
            jsonb_build_object('basePoints', v_model_option.points, 'wargearPoints', v_wargear_points),
          updated_at = now()
      where id = v_unit.id;
    end loop;

    for v_queue in
      select * from public.recruitment_queue
      where unit_template_id = v_template.id and status = 'queued'
      for update
    loop
      select * into v_model_option
      from public.unit_template_model_options
      where unit_template_id = v_template.id
        and min_models <= coalesce(v_queue.selected_model_count, v_template.default_quantity)
        and max_models >= coalesce(v_queue.selected_model_count, v_template.default_quantity)
        and copy_from = 1
      order by max_models, min_models desc
      limit 1;

      if not found then
        raise exception 'MFM has no first-copy queue price for %', v_template.slug;
      end if;

      select coalesce(jsonb_agg(
        selected.value || jsonb_build_object(
          'points', coalesce(wargear.points, (selected.value->>'points')::integer, 0),
          'totalPoints', coalesce(wargear.points, (selected.value->>'points')::integer, 0)
            * coalesce((selected.value->>'quantity')::integer, 1)
        )
      ), '[]'::jsonb)
      into v_wargear_options
      from jsonb_array_elements(coalesce(v_queue.selected_wargear_options, '[]'::jsonb)) as selected(value)
      left join public.unit_template_wargear_options as wargear
        on wargear.unit_template_id = v_template.id and wargear.slug = selected.value->>'slug';

      select coalesce(sum((selected.value->>'totalPoints')::integer), 0)
      into v_wargear_points
      from jsonb_array_elements(v_wargear_options) as selected(value);

      update public.recruitment_queue
      set selected_points = v_model_option.points + v_wargear_points,
          selected_model_option_id = v_model_option.id,
          selected_wargear_points = v_wargear_points,
          selected_wargear_options = v_wargear_options,
          point_cost_breakdown = coalesce(point_cost_breakdown, '{}'::jsonb) ||
            jsonb_build_object('basePoints', v_model_option.points, 'wargearPoints', v_wargear_points),
          updated_at = now()
      where id = v_queue.id;
    end loop;
  end loop;

  update public.battle_unit_commitments as commitment
  set points_at_commitment = unit.points, updated_at = now()
  from public.campaign_units as unit
  where commitment.unit_id = unit.id
    and unit.faction_id = (select id from public.factions where slug = 'necrones')
    and commitment.status in ('en_route', 'in_battle', 'returning');
end;
$$;
