import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface SubmissionData {
  prenom: string;
  nom: string;
  email: string;
  classe?: string;
  ligne1: string;
  ligne2: string;
  ligne3: string;
  theme: string;
  formats: string;
  intention?: string;
  consentement: boolean;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    if (req.method === "POST") {
      const formData = await req.formData();

      const submissionData: SubmissionData = {
        prenom: formData.get('prenom') as string,
        nom: formData.get('nom') as string,
        email: formData.get('email') as string,
        classe: formData.get('classe') as string || undefined,
        ligne1: formData.get('ligne1') as string,
        ligne2: formData.get('ligne2') as string,
        ligne3: formData.get('ligne3') as string,
        theme: formData.get('theme') as string,
        formats: formData.get('formats') as string,
        intention: formData.get('intention') as string || undefined,
        consentement: formData.get('consentement') === 'true',
      };

      if (!submissionData.prenom || !submissionData.nom || !submissionData.email ||
          !submissionData.ligne1 || !submissionData.ligne2 || !submissionData.ligne3 ||
          !submissionData.theme || !submissionData.formats) {
        return new Response(
          JSON.stringify({ error: 'Champs obligatoires manquants' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      let fileUrl: string | null = null;
      let fileName: string | null = null;
      let fileType: string | null = null;

      const file = formData.get('file') as File | null;
      if (file) {
        const timestamp = Date.now();
        const sanitizedFileName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
        const storagePath = `${timestamp}_${sanitizedFileName}`;

        const fileBuffer = await file.arrayBuffer();
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('haiku-media')
          .upload(storagePath, fileBuffer, {
            contentType: file.type,
            upsert: false,
          });

        if (uploadError) {
          console.error('Upload error:', uploadError);
          return new Response(
            JSON.stringify({ error: 'Erreur lors de l\'upload du fichier' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const { data: urlData } = supabase.storage
          .from('haiku-media')
          .getPublicUrl(storagePath);

        fileUrl = urlData.publicUrl;
        fileName = file.name;
        fileType = file.type;
      }

      const { data, error } = await supabase
        .from('haiku_submissions')
        .insert([{
          ...submissionData,
          file_url: fileUrl,
          file_name: fileName,
          file_type: fileType,
          status: 'pending',
        }])
        .select()
        .single();

      if (error) {
        console.error('Database error:', error);
        return new Response(
          JSON.stringify({ error: 'Erreur lors de l\'enregistrement' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Soumission enregistrée avec succès',
          id: data.id
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (req.method === "GET") {
      const { data, error } = await supabase
        .from('haiku_submissions')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        return new Response(
          JSON.stringify({ error: 'Erreur lors de la récupération des données' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ submissions: data }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Méthode non supportée' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('Server error:', err);
    return new Response(
      JSON.stringify({ error: 'Erreur serveur interne' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
