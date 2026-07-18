// Reemplazá estos dos valores con los de tu proyecto Supabase
// (Project Settings -> API -> Project URL / anon public key).
// La "anon key" es pública y segura de exponer en el frontend
// SIEMPRE Y CUANDO tengas RLS activado en las tablas sensibles.
const SUPABASE_URL = "https://xwbcckdhkuzkedzgtwma.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3YmNja2Roa3V6a2Vkemd0d21hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMTE1ODgsImV4cCI6MjA5OTg4NzU4OH0.zFcTwq7z8gJeMBKCrKf-KGH25Hv3rHaAsYk7_eq7bsE";

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
