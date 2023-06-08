import { ConnectButton } from "@rainbow-me/rainbowkit";
import styles from "../../styles/Navbar.module.css";
export default function Navbar() {
	return (
		<nav className={styles.navbar}>
			<a href="https://stargate.finance" target={"_blank"}>
				<h1>OmniMint</h1>
			</a>
			<ConnectButton></ConnectButton>
		</nav>
	);
}
