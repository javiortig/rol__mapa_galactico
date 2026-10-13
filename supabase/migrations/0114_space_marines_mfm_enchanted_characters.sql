-- Space Marines prices from the official MFM, refreshed on 2026-10-13.
-- Existing resources, completed recruitment history and destroyed units are untouched.
do $$
declare
  -- BEGIN GENERATED SPACE MARINES MFM PAYLOAD
  v_items jsonb := $mfm$[{"slug":"unit-space-marines-ancient","points":40,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":40,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-ancient-in-terminator-armor","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-apothecary","points":45,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":45,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-apothecary-biologis","points":60,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-10}],"wargear":[]},{"slug":"unit-space-marines-bladeguard-ancient","points":70,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":70,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":30}],"wargear":[]},{"slug":"unit-space-marines-captain","points":90,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-captain-in-gravis-armour","points":90,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-captain-in-phobos-armour","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-captain-in-terminator-armour","points":90,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-captain-with-jump-pack","points":90,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":15}],"wargear":[]},{"slug":"unit-space-marines-chaplain","points":60,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-chaplain-in-terminator-armour","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-chaplain-on-bike","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-chaplain-with-jump-pack","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-judiciar","points":50,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":50,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-5}],"wargear":[]},{"slug":"unit-space-marines-librarian","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-librarian-in-phobos-armour","points":75,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":75,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-librarian-in-terminator-armour","points":80,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-5}],"wargear":[]},{"slug":"unit-space-marines-lieutenant","points":50,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":50,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-lieutenant-in-phobos-armour","points":40,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":40,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-5}],"wargear":[]},{"slug":"unit-space-marines-lieutenant-with-combi-weapon","points":85,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-10}],"wargear":[]},{"slug":"unit-space-marines-techmarine","points":55,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":55,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-assault-intercessor-squad","points":85,"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":170,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]},{"slug":"unit-space-marines-heavy-intercessor-squad","points":115,"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":115,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":15},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":230,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":30}],"wargear":[]},{"slug":"unit-space-marines-intercessor-squad","points":85,"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":170,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]},{"slug":"unit-space-marines-aggressor-squad","points":90,"models":[{"slug":"models-3-3-copy-1-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":90,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10},{"slug":"models-6-6-copy-1-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":180,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":15}],"wargear":[]},{"slug":"unit-space-marines-assault-intercessors-with-jump-packs","points":95,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":95,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":190,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":30},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":105,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":10},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":200,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":30}],"wargear":[]},{"slug":"unit-space-marines-astraeus","points":550,"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":550,"copyFrom":1,"copyTo":1,"changeDirection":"up","changeAmount":25},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":650,"copyFrom":2,"copyTo":null,"changeDirection":"up","changeAmount":75}],"wargear":[]},{"slug":"unit-space-marines-ballistus-dreadnought","points":150,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":150,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":170,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-bladeguard-veteran-squad","points":90,"models":[{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":90,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-6-6-copy-1-2","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":180,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":20},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":110,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":20},{"slug":"models-6-6-copy-3-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":200,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":30}],"wargear":[]},{"slug":"unit-space-marines-brutalis-dreadnought","points":160,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":160,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":180,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]},{"slug":"unit-space-marines-company-heroes","points":125,"models":[{"slug":"models-4-4-copy-1-2","label":"4 models","models":4,"minModels":4,"maxModels":4,"points":125,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":20},{"slug":"models-4-4-copy-3-plus","label":"4 models","models":4,"minModels":4,"maxModels":4,"points":145,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-desolation-squad","points":140,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":140,"copyFrom":1,"copyTo":2,"changeDirection":"down","changeAmount":-40},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":150,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[{"slug":"vengor-launcher","name":"Vengor Launcher","points":5,"pricing":"per_option","changeDirection":null,"changeAmount":null}]},{"slug":"unit-space-marines-drop-pod","points":60,"models":[{"slug":"models-1-1-copy-1-3","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":60,"copyFrom":1,"copyTo":3,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-4-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":70,"copyFrom":4,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-eliminator-squad","points":85,"models":[{"slug":"models-3-3-copy-1-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-firestrike-servo-turrets","points":80,"models":[{"slug":"models-1-1-copy-1-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":5},{"slug":"models-2-2-copy-1-plus","label":"2 models","models":2,"minModels":2,"maxModels":2,"points":160,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-gladiator-lancer","points":160,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":160,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":180,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":10}],"wargear":[]},{"slug":"unit-space-marines-gladiator-reaper","points":165,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":165,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":185,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":15}],"wargear":[]},{"slug":"unit-space-marines-gladiator-valiant","points":165,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":165,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":15},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":185,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":25}],"wargear":[]},{"slug":"unit-space-marines-hellblaster-squad","points":115,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":115,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":230,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":130,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":245,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-impulsor","points":70,"models":[{"slug":"models-1-1-copy-1-3","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":70,"copyFrom":1,"copyTo":3,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-4-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":4,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[{"slug":"orbital-comms-array","name":"Orbital Comms Array","points":10,"pricing":"per_option","changeDirection":null,"changeAmount":null}]},{"slug":"unit-space-marines-inceptor-squad","points":130,"models":[{"slug":"models-3-3-copy-1-2","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":130,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-6-6-copy-1-2","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":260,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-3-3-copy-3-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":150,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":10},{"slug":"models-6-6-copy-3-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":280,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":15}],"wargear":[]},{"slug":"unit-space-marines-incursor-squad","points":90,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":90,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":170,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":20},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":100,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":5},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":180,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]},{"slug":"unit-space-marines-infernus-squad","points":95,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":95,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":190,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":105,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":200,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-infiltrator-squad","points":85,"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-25},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":150,"copyFrom":1,"copyTo":null,"changeDirection":"down","changeAmount":-30}],"wargear":[]},{"slug":"unit-space-marines-invictor-tactical-warsuit","points":135,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":135,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":150,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-land-raider","points":245,"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":245,"copyFrom":1,"copyTo":1,"changeDirection":"up","changeAmount":25},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":265,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-land-raider-crusader","points":230,"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":230,"copyFrom":1,"copyTo":1,"changeDirection":"up","changeAmount":10},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":250,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-land-raider-redeemer","points":245,"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":245,"copyFrom":1,"copyTo":1,"changeDirection":"down","changeAmount":-15},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":265,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-outrider-squad","points":80,"models":[{"slug":"models-3-3-copy-1-plus","label":"3 models","models":3,"minModels":3,"maxModels":3,"points":80,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10},{"slug":"models-6-6-copy-1-plus","label":"6 models","models":6,"minModels":6,"maxModels":6,"points":160,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]},{"slug":"unit-space-marines-redemptor-dreadnought","points":170,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":170,"copyFrom":1,"copyTo":2,"changeDirection":"down","changeAmount":-25},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":190,"copyFrom":3,"copyTo":null,"changeDirection":"down","changeAmount":-20}],"wargear":[{"slug":"macro-plasma-incinerator","name":"Macro Plasma Incinerator","points":10,"pricing":"per_option","changeDirection":null,"changeAmount":null}]},{"slug":"unit-space-marines-reiver-squad","points":85,"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":85,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":10},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":165,"copyFrom":1,"copyTo":null,"changeDirection":"up","changeAmount":15}],"wargear":[]},{"slug":"unit-space-marines-repulsor","points":190,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":190,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":20},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":210,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]},{"slug":"unit-space-marines-repulsor-executioner","points":260,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":260,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":280,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[{"slug":"heavy-laser-destroyer","name":"Heavy Laser Destroyer","points":10,"pricing":"per_option","changeDirection":null,"changeAmount":null}]},{"slug":"unit-space-marines-rhino","points":70,"models":[{"slug":"models-1-1-copy-1-3","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":70,"copyFrom":1,"copyTo":3,"changeDirection":"up","changeAmount":5},{"slug":"models-1-1-copy-4-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":80,"copyFrom":4,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-scout-squad","points":65,"models":[{"slug":"models-5-5-copy-1-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":65,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-1-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":120,"copyFrom":1,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-sternguard-veteran-squad","points":105,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":105,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":210,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":120,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":225,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-storm-speeder-hailstrike","points":110,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":110,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":120,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-storm-speeder-hammerstrike","points":140,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":140,"copyFrom":1,"copyTo":2,"changeDirection":null,"changeAmount":null},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":150,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-storm-speeder-thunderstrike","points":140,"models":[{"slug":"models-1-1-copy-1-2","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":140,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-1-1-copy-3-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":150,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":5}],"wargear":[]},{"slug":"unit-space-marines-terminator-assault-squad","points":170,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":170,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":15},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":340,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":30},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":210,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":380,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[{"slug":"storm-shield","name":"Storm Shield","points":5,"pricing":"per_option","changeDirection":null,"changeAmount":null}]},{"slug":"unit-space-marines-terminator-squad","points":190,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":190,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":30},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":380,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":60},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":230,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":420,"copyFrom":3,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[{"slug":"cyclone-missile-launcher","name":"Cyclone Missile Launcher","points":10,"pricing":"per_option","changeDirection":null,"changeAmount":null}]},{"slug":"unit-space-marines-thunderhawk-gunship","points":850,"models":[{"slug":"models-1-1-copy-1-1","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":850,"copyFrom":1,"copyTo":1,"changeDirection":"up","changeAmount":10},{"slug":"models-1-1-copy-2-plus","label":"1 model","models":1,"minModels":1,"maxModels":1,"points":950,"copyFrom":2,"copyTo":null,"changeDirection":null,"changeAmount":null}],"wargear":[]},{"slug":"unit-space-marines-vanguard-veteran-squad-with-jump-packs","points":110,"models":[{"slug":"models-5-5-copy-1-2","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":110,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":5},{"slug":"models-10-10-copy-1-2","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":220,"copyFrom":1,"copyTo":2,"changeDirection":"up","changeAmount":10},{"slug":"models-5-5-copy-3-plus","label":"5 models","models":5,"minModels":5,"maxModels":5,"points":130,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":15},{"slug":"models-10-10-copy-3-plus","label":"10 models","models":10,"minModels":10,"maxModels":10,"points":240,"copyFrom":3,"copyTo":null,"changeDirection":"up","changeAmount":20}],"wargear":[]}]$mfm$::jsonb;
    -- END GENERATED SPACE MARINES MFM PAYLOAD
  v_item jsonb;
  v_option jsonb;
  v_template public.unit_templates%rowtype;
  v_model_option public.unit_template_model_options%rowtype;
  v_unit public.campaign_units%rowtype;
  v_queue public.recruitment_queue%rowtype;
  v_cost record;
  v_wargear_options jsonb;
  v_wargear_points integer;
begin
  for v_item in select value from jsonb_array_elements(v_items) loop
    select * into v_template
    from public.unit_templates
    where slug = v_item->>'slug'
      and faction_id = (select id from public.factions where slug = 'space-marines')
    for update;

    if not found then
      continue;
    end if;

    select * into v_cost
    from public.recruitment_cost_bundle_for_template(v_template.id, (v_item->>'points')::integer);

    update public.unit_templates
    set points = (v_item->>'points')::integer,
        supply_cost = v_cost.supply_cost,
        minerals_cost = v_cost.minerals_cost,
        honor_cost = v_cost.honor_cost,
        gold_cost = v_cost.gold_cost
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
    and unit.faction_id = (select id from public.factions where slug = 'space-marines')
    and commitment.status in ('en_route', 'in_battle', 'returning');
end;
$$;

alter table public.recruitment_queue
  add column if not exists is_enchanted boolean not null default false;

alter table public.campaign_units
  add column if not exists is_enchanted boolean not null default false;

alter table public.campaign_units
  add constraint campaign_units_enchantment_character_check
  check (not is_enchanted or unit_type = 'character' or 'Caracter' = any(unit_keywords));

create or replace function public.recruit_unit_variant_at_building(
  system_building_id uuid,
  unit_template_id uuid,
  model_count integer,
  wargear_selections jsonb,
  enchanted boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template public.unit_templates%rowtype;
  v_queue public.recruitment_queue%rowtype;
  v_queue_id uuid;
begin
  if not coalesce(enchanted, false) then
    return public.recruit_unit_variant_at_building(
      system_building_id, unit_template_id, model_count, wargear_selections
    );
  end if;

  select * into v_template from public.unit_templates where id = unit_template_id;
  if not found or not (
    v_template.unit_type = 'character' or 'Caracter' = any(v_template.unit_keywords)
  ) then
    raise exception 'Solo los caracteres pueden reclutarse encantados';
  end if;

  v_queue_id := public.recruit_unit_variant_at_building(
    system_building_id, unit_template_id, model_count, wargear_selections
  );

  select * into v_queue from public.recruitment_queue where id = v_queue_id for update;
  if not found then
    raise exception 'No se pudo crear la cola de reclutamiento';
  end if;

  update public.faction_resources
  set honor = honor - 4, updated_at = now()
  where faction_id = v_queue.faction_id and honor >= 4;

  if not found then
    raise exception 'Honor insuficiente para encantar el caracter';
  end if;

  update public.recruitment_queue
  set is_enchanted = true, honor_cost = honor_cost + 4, updated_at = now()
  where id = v_queue_id;

  insert into public.campaign_logs (actor_user_id, faction_id, action_type, payload)
  values (auth.uid(), v_queue.faction_id, 'character_enchantment_commissioned',
    jsonb_build_object('queue_id', v_queue_id, 'unit_template_id', unit_template_id, 'honor_cost', 4));

  return v_queue_id;
end;
$$;

revoke execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb, boolean)
  from public, anon;
grant execute on function public.recruit_unit_variant_at_building(uuid, uuid, integer, jsonb, boolean)
  to authenticated;

create or replace function public.resolve_recruitment_queue()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_unit_id uuid;
  v_index integer;
  v_created integer := 0;
  v_unit_points integer;
  v_unit_models integer;
begin
  for v_item in
    select recruitment_queue.*, unit_templates.name as unit_name,
      unit_templates.category, unit_templates.unit_type, unit_templates.unit_keywords,
      unit_templates.points, unit_templates.default_quantity, factions.capital_system_id
    from public.recruitment_queue
    join public.unit_templates on unit_templates.id = recruitment_queue.unit_template_id
    join public.factions on factions.id = recruitment_queue.faction_id
    where recruitment_queue.status = 'queued'
      and recruitment_queue.finishes_at <= now()
      and not public.system_has_unresolved_battle_block(
        coalesce(recruitment_queue.origin_system_id, factions.capital_system_id)
      )
    order by recruitment_queue.finishes_at
    for update of recruitment_queue
  loop
    v_unit_points := coalesce(v_item.selected_points, v_item.points);
    v_unit_models := coalesce(v_item.selected_model_count, v_item.default_quantity);

    for v_index in 1..v_item.quantity loop
      insert into public.campaign_units (
        slug, faction_id, unit_template_id, name, category, unit_type, unit_keywords,
        points, quantity, starting_quantity, wounds_taken, experience,
        current_system_id, status, is_visible_publicly, selected_model_option_id,
        selected_wargear_points, selected_wargear_options, point_cost_breakdown,
        is_enchanted
      ) values (
        'recruited-' || v_item.id::text || '-' || v_index::text,
        v_item.faction_id, v_item.unit_template_id, v_item.unit_name, v_item.category,
        v_item.unit_type, v_item.unit_keywords, v_unit_points, v_unit_models,
        v_unit_models, 0, 0,
        coalesce(v_item.origin_system_id, v_item.capital_system_id),
        'ready', false, v_item.selected_model_option_id, v_item.selected_wargear_points,
        v_item.selected_wargear_options, v_item.point_cost_breakdown,
        v_item.is_enchanted
      ) returning id into v_unit_id;

      insert into public.campaign_logs (faction_id, action_type, payload)
      values (v_item.faction_id, 'recruitment_completed', jsonb_build_object(
        'queue_id', v_item.id, 'unit_id', v_unit_id,
        'unit_template_id', v_item.unit_template_id, 'unit_name', v_item.unit_name,
        'quantity', v_unit_models, 'points', v_unit_points,
        'is_enchanted', v_item.is_enchanted,
        'origin_system_id', coalesce(v_item.origin_system_id, v_item.capital_system_id)
      ));

      v_created := v_created + 1;
    end loop;

    update public.recruitment_queue
    set status = 'completed', updated_at = now()
    where id = v_item.id;
  end loop;

  return v_created;
end;
$$;

notify pgrst, 'reload schema';
