import './globals.css';
import type { Metadata } from 'next';
export const metadata: Metadata = {title:'Retail Store',description:'Дэлгүүрийн бараа, борлуулалт, кассын удирдлага'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="mn"><body>{children}</body></html>}
