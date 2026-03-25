/*
  # Création de la base de données pour le concours de haïku

  ## Résumé
  Ce fichier crée la structure complète pour gérer les inscriptions au concours "Le Monde à la Loupe".
  
  ## 1. Nouvelles Tables
  
  ### `haiku_submissions`
  Table principale pour stocker toutes les inscriptions au concours
  - `id` (uuid, clé primaire) - Identifiant unique de la soumission
  - `prenom` (text) - Prénom du participant
  - `nom` (text) - Nom du participant
  - `email` (text) - Email pour recontacter le participant
  - `classe` (text, nullable) - Classe/niveau (facultatif)
  - `ligne1` (text) - Première ligne du haïku
  - `ligne2` (text) - Deuxième ligne du haïku
  - `ligne3` (text) - Troisième ligne du haïku
  - `theme` (text) - Thème choisi (loupe, choses, royaumes, sol)
  - `formats` (text) - Formats de création choisis (séparés par virgules)
  - `intention` (text, nullable) - Intention créative (facultatif)
  - `consentement` (boolean) - Acceptation de partage
  - `file_url` (text, nullable) - URL vers le fichier uploadé dans Supabase Storage
  - `file_name` (text, nullable) - Nom original du fichier
  - `file_type` (text, nullable) - Type MIME du fichier
  - `created_at` (timestamptz) - Date et heure de soumission
  - `status` (text) - Statut de la soumission (pending, reviewed, selected, rejected)
  
  ## 2. Sécurité (RLS)
  - Enable RLS sur la table `haiku_submissions`
  - Les utilisateurs anonymes peuvent INSERT (soumettre leur création)
  - Seuls les administrateurs authentifiés peuvent SELECT/UPDATE/DELETE
  
  ## 3. Storage Bucket
  - Création d'un bucket public "haiku-media" pour stocker les fichiers
  - Limite de taille: 50MB par fichier
  - Types acceptés: images, vidéos, audio, PDF
  
  ## 4. Index
  - Index sur `email` pour recherche rapide
  - Index sur `created_at` pour tri chronologique
  - Index sur `status` pour filtrage par statut
*/

-- Créer la table des soumissions
CREATE TABLE IF NOT EXISTS haiku_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prenom text NOT NULL,
  nom text NOT NULL,
  email text NOT NULL,
  classe text,
  ligne1 text NOT NULL,
  ligne2 text NOT NULL,
  ligne3 text NOT NULL,
  theme text NOT NULL,
  formats text NOT NULL,
  intention text,
  consentement boolean DEFAULT false,
  file_url text,
  file_name text,
  file_type text,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

-- Activer Row Level Security
ALTER TABLE haiku_submissions ENABLE ROW LEVEL SECURITY;

-- Politique : Les utilisateurs anonymes peuvent soumettre (INSERT)
CREATE POLICY "Anyone can submit haiku"
  ON haiku_submissions
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Politique : Seuls les utilisateurs authentifiés peuvent consulter toutes les soumissions
CREATE POLICY "Authenticated users can view all submissions"
  ON haiku_submissions
  FOR SELECT
  TO authenticated
  USING (true);

-- Politique : Seuls les utilisateurs authentifiés peuvent mettre à jour
CREATE POLICY "Authenticated users can update submissions"
  ON haiku_submissions
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Politique : Seuls les utilisateurs authentifiés peuvent supprimer
CREATE POLICY "Authenticated users can delete submissions"
  ON haiku_submissions
  FOR DELETE
  TO authenticated
  USING (true);

-- Créer des index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_haiku_email ON haiku_submissions(email);
CREATE INDEX IF NOT EXISTS idx_haiku_created_at ON haiku_submissions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_haiku_status ON haiku_submissions(status);

-- Créer le bucket de stockage pour les fichiers média
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'haiku-media',
  'haiku-media',
  true,
  52428800, -- 50MB en octets
  ARRAY[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'video/mp4',
    'video/quicktime',
    'audio/mpeg',
    'audio/mp3',
    'application/pdf'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Politique de stockage : Permettre l'upload anonyme
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Allow anonymous uploads to haiku-media'
  ) THEN
    CREATE POLICY "Allow anonymous uploads to haiku-media"
      ON storage.objects
      FOR INSERT
      TO anon
      WITH CHECK (bucket_id = 'haiku-media');
  END IF;
END $$;

-- Politique de stockage : Permettre la lecture publique
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Allow public read access to haiku-media'
  ) THEN
    CREATE POLICY "Allow public read access to haiku-media"
      ON storage.objects
      FOR SELECT
      TO public
      USING (bucket_id = 'haiku-media');
  END IF;
END $$;

-- Politique de stockage : Permettre la suppression authentifiée
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Allow authenticated delete from haiku-media'
  ) THEN
    CREATE POLICY "Allow authenticated delete from haiku-media"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (bucket_id = 'haiku-media');
  END IF;
END $$;