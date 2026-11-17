<<<<<<< HEAD
import './globals.css';
export const metadata = {title:'Дэлгүүрийн удирдлага',description:'Бараа, борлуулалт, зардлын бүртгэл'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="mn"><body>{children}</body></html>}
=======
import type {Metadata} from "next";
export const metadata:Metadata={title:"Retail Store",description:"Жижиг дэлгүүрийн бүртгэлийн систем"};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="mn"><body style={{margin:0,fontFamily:"Arial,sans-serif",background:"#f7f8fa",color:"#19232c"}}>{children}</body></html>}
>>>>>>> ea8eee933ceaf74f9c25a9f75a8be4a3f2e946cd
