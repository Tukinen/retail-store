import type {Metadata} from "next";
export const metadata:Metadata={title:"Retail Store",description:"Жижиг дэлгүүрийн бүртгэлийн систем"};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="mn"><body style={{margin:0,fontFamily:"Arial,sans-serif",background:"#f7f8fa",color:"#19232c"}}>{children}</body></html>}
