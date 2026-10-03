## MyBot 12.0.2

**À faire après la mise à jour :** si un bandeau « Réglages du profil à réparer » apparaît sur le tableau de bord, fermez le bot puis cliquez sur **Réparer le profil**. Les versions 12.0.0 et 12.0.1 enregistraient les nouveaux profils avec de mauvaises valeurs (butin minimum à 0, fin de combat à 0, aucune heure de dons, mode arrière-plan coupé…). La réparation remet ces réglages par défaut, garde ce que vous avez changé vous-même et fait une copie du profil avant.

### Corrections
- Nouveaux profils enregistrés avec de mauvaises valeurs : corrigé, et réparation proposée pour les profils existants.
- Émulateur en partie hors de l'écran sans mode arrière-plan : capture noire, fausse détection de langue, dézoom interminable. Le bot le signale maintenant.
- « Démarrer » pendant le chargement du bot n'est plus refusé.
- Dézoom environ deux fois plus rapide.
- Trophées de la base des ouvriers lus correctement (2294 était lu 91).
- Récompenses de combat (« Pick a Reward ») : l'élixir noir est pris quand il n'y a ni or ni élixir ; le combat ne s'arrête plus tant que de l'élixir noir est encore pillé.
- Engin de siège qui ne passait pas au château de clan : n'est plus lâché comme « 1 Barbarian ».
- BlueStacks 5.22.265 pris en charge ; une fenêtre BlueStacks réduite n'est plus prise pour une fenêtre fermée.
- Murs : le nombre de murs de chaque niveau est tenu par le bot, plus rien à remplir.

### Interface
- Thème sombre noir, thème clair gris, case « Suivre le thème de Windows ».
- Couleur d'accent de Windows et couleur noir et blanc.
- Interface en français ou en anglais (Réglages › Langue).
- Pages de réglages sans espaces vides entre les cartes.
- Temps de run : ne repart plus à zéro en fin d'attaque, se fige pendant les pauses.
- Statut Discord : application MyBot intégrée, un seul interrupteur, version affichée (« MyBotRun_v12.0.2 »).

Détail complet : voir le fichier CHANGELOG.

---

**After updating:** if a "Profile settings to repair" banner shows on the dashboard, close the bot and click **Repair the profile** (12.0.0 and 12.0.1 saved new profiles with wrong settings; your own changes are kept and a copy is made first). Full list of changes in CHANGELOG.
