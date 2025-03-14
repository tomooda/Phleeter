Class {
	#name : 'BaselineOfPhleeter',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPhleeter',
	#package : 'BaselineOfPhleeter'
}

{ #category : 'baselines' }
BaselineOfPhleeter >> baseline: spec [

	<baseline>
	spec for: #common do: [
		spec blessing: #baseline.
		spec
			baseline: 'ApplicationGenerator'
			with: [
				spec repository: 'github://tesonep/PharoApplicationGenerator/src' ];
			package: 'Phleeter-Core'
			with: [ spec requires: #( 'ApplicationGenerator' ) ];
			group: 'default' with: #( 'Phleeter-Core' ) ]
]
