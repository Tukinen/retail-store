<<<<<<< HEAD
# Жижиглэнгийн дэлгүүр — MVP 2

## Суулгах
1. Node.js 20+ суулгана.
2. Supabase төсөл үүсгээд SQL Editor-д `supabase/schema.sql`, **дараа нь** `supabase/v2_migration.sql` файлыг ажиллуулна. Өмнө нь schema.sql ажиллуулсан бол зөвхөн migration-ийг ажиллуул.
3. `.env.example` → `.env.local` болгож URL болон publishable/anon key-г оруул. Service-role key-г вебэд **хэзээ ч** оруулахгүй.
4. `npm install && npm run dev` ажиллуулаад localhost:3000 нээнэ.
5. GitHub + Vercel дээр deploy хийж, Vercel Environment Variables болон Supabase Auth Redirect URLs-ийг тохируулна.

## MVP 2
- Нэг баримт олон барааны мөртэй, бэлэн/данс/POS хуваасан төлбөртэй; баримт болон барааны үлдэгдэл нэг SQL transaction-д атомик бичигдэнэ.
- Дахин татан авалтад хөдөлгөөнт жигнэсэн дундаж өртөг; борлуулалтын өртгийг тухайн үеийн snapshot байдлаар хадгална.
- Буцаалтыг анхны баримтын мөртэй холбож, тоог давхар буцаахаас сэргийлнэ. Дахин зарах боломжтой буцаалтын барааг анхны борлуулалтын өртгөөр одоогийн дундажид оруулна; гэмтэлтэй буцаалтыг үлдэгдэлд оруулахгүй.
- Кассын ээлж нээх/хаах, бодит тоолол, зөрүү, тайлбар; зөвхөн бэлэн мөнгөний гүйлгээг тооцно.
- CSV тайлан. Зураг Supabase private storage-д.

## Нөөцлөлт — хамгийн хямд практик хувилбар
Supabase-ийн үнэгүй багцын PITR/автомат backup боломжийг **баталгаатай гэж үзэж болохгүй**. Өдөр бүр нэг удаа `pg_dump` ашиглан PostgreSQL өгөгдлийн сангийн **custom-format** backup авч, шифрлээд өөр үйлчилгээний хадгалалт руу хуул. GitHub Actions schedule + GitHub encrypted secrets + тусдаа cloud storage (жишээ нь R2/S3 compatible) тохируулах боломжтой; үнэ, лимит, сүлжээний зөвшөөрөл болон үйлчилгээний бодлогыг тухайн үед шалга. GitHub Actions artifacts-ийг цорын ганц урт хугацааны backup гэж үзэж болохгүй. Product image файлуудыг Storage API-гаар тусад нь татаж хадгалах шаардлагатай — `pg_dump` зураг файлын bytes-ийг нөөцлөхгүй. Backup шифрлэлтийн түлхүүрийг backup-аас тусад нь хадгал. 7 өдөр + 4 долоо хоног + 3 сар хадгалалт, сар бүр туршилтын сэргээх ажиллагаа зөвлөмжтэй.

## Хязгаар ба production checklist
- Эхний хувилбарын `products` INSERT, `expenses` INSERT-ийг эзэмшигч өөрөө хийх боломжтой. Олон ажилтан, роль, зөвшөөрөл, аудитын бүрэн бүртгэл хараахан байхгүй.
- Буцаалт анхны төлбөрийн **төрөл** байсан эсэхийг шалгана, гэхдээ тухайн төрлөөр төлсөн дүнгийн хязгаарыг шалгахгүй. Split payment бүхий буцаалтыг касс хариуцсан ажилтан хянах ёстой.
- Бэлэн кассын нээлттэй ээлжээс өмнө/дараах гүйлгээ, бэлэн мөнгө оруулах/гаргах тусдаа хөдөлгөөн, банк/POS-ийн бодит хуулгатай тулгалт одоогоор байхгүй. Касс нээхээс өмнө бэлэн борлуулалт хийхийг SQL түвшинд хориглоогүй.
- Гэмтэлтэй буцаалт нь борлуулалтын өртгийг буцааж нэмэхгүй тул хорогдлын зардалд үлдэнэ; тусгай write-off журнал одоогоор байхгүй.
- Барааны эхний үлдэгдлийг шууд бүртгэхэд stock_movements-д эхний хөдөлгөөн үүсэхгүй. Эхний өртгийг анхны дундаж гэж үзнэ.
- Өмнөх `sales` мөрүүд шинэ receipt тайланд **автоматаар шилжихгүй**. Хуучин өгөгдөлтэй бол шилжүүлэлтийн тусгай ажил хэрэгтэй.
- Тайлан client-side, хүснэгт тус бүр 10,000 мөр хүртэл; их хэмжээний дата дээр server-side aggregation шаардлагатай.
- Энэ кодыг live Supabase/Vercel дээр туршаагүй. Production ашиглалтаас өмнө RLS, concurrent sale, split payment, refund, cash close, restore test хий.
=======
# Retail Store
Next.js + Supabase retail inventory and receipt application.

Configure NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY in Vercel. Database migrations were applied in Supabase. This is an initial deployment and requires transactional and security testing before real-money use.
>>>>>>> ea8eee933ceaf74f9c25a9f75a8be4a3f2e946cd
