import styles from "../styles/InstructionsComponent.module.css";
import Router, { useRouter } from "next/router";
import { useContractWrite, usePrepareContractWrite, useProvider, useAccount } from "wagmi";
import { useEffect } from "react";
import { addresses } from "../constants/addresses"
import { parseEther } from "ethers/lib/utils.js";

export default function MintComponent() {
	const router = useRouter();
	const provider = useProvider();
	const account = useAccount();

	const COST_PER_NFT = 0.05;

	let chainId = provider.network.chainId;

	const Contract = usePrepareContractWrite({
		address: addresses[chainId.toString()],
		abi: [{
			"inputs": [
			  {
				"internalType": "uint256",
				"name": "_amount",
				"type": "uint256"
			  },
			  {
				"internalType": "uint256",
				"name": "_fee",
				"type": "uint256"
			  }
			],
			"name": "mint",
			"outputs": [],
			"stateMutability": "payable",
			"type": "function"
		  }],
		functionName: 'mint',
		args: ['1'],
		value: parseEther((1 * COST_PER_NFT).toString())
	});
	const mint = useContractWrite(Contract.config)

	useEffect(() => {
		let chainId = provider.network.chainId;
	}, [])

	return (
		<div className={styles.container}>
			<header className={styles.header_container}>
				<h1>
					<span>Mint Now!</span>
				</h1>
			</header>

			<div className={styles.buttons_container}>
				{
					addresses[chainId] ? 
					<a>
						<div className={styles.button} onClick={mint.write}>
							{/* <img src="https://static.alchemyapi.io/images/cw3d/Icon%20Medium/lightning-square-contained-m.svg" width={"20px"} height={"20px"} /> */}
							<p>Mint NFT</p>
						</div>
					</a>
					:
					<>
					</>
				} 
			</div>
			<p className={styles.p}>Made with ❤️ by <a href={"https://twitter.com/gajeshnaik"}>Gajesh Naik</a></p>
		</div>
	);
}
